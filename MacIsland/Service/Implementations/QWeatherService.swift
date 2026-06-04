//
//  QWeatherService.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation
import Combine
import CoreLocation

/// 和风天气 API 服务实现
final class QWeatherService: WeatherServiceProtocol, ObservableObject {
    @Published private(set) var weather: WeatherData = .empty
    @Published private(set) var isLoading = false

    private let config: QWeatherConfig
    private let networkClient: NetworkClientProtocol
    private let locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    private var locationDelegate: LocationDelegate?
    private var cachedLocationInfo: (id: String, city: String, district: String)?

    init(config: QWeatherConfig, networkClient: NetworkClientProtocol = URLSession.shared) {
        self.config = config
        self.networkClient = networkClient
        setupLocationManager()
    }

    func fetchWeather() async {
        await MainActor.run { isLoading = true }
        defer { Task { @MainActor in isLoading = false } }

        // 第一步：获取位置信息（坐标 + GeoAPI 查询 locationID）
        let locationInfo = await fetchLocationInfo()

        guard let locInfo = locationInfo else {
            setError("获取位置失败")
            return
        }

        // 第二步：使用 locationID 查询天气
        async let nowResult = fetchNowWeather(locationID: locInfo.id)
        async let forecastResult = fetchForecast(locationID: locInfo.id)

        let (now, forecast) = await (nowResult, forecastResult)

        guard let nowData = now else {
            setError("获取天气失败")
            return
        }

        await MainActor.run {
            weather = WeatherData(
                temperature: nowData.temp,
                temperatureMax: forecast?.maxTemp ?? nowData.temp,
                temperatureMin: forecast?.minTemp ?? nowData.temp,
                humidity: nowData.humidity,
                windSpeed: nowData.windSpeed,
                windDir: nowData.windDir,
                weatherCode: nowData.code,
                description: nowData.text,
                iconSystemName: WeatherIconMapper.iconName(for: nowData.code),
                cityName: locInfo.city,
                districtName: locInfo.district
            )
        }
    }

    // MARK: - Location Setup

    private func setupLocationManager() {
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.requestWhenInUseAuthorization()
    }

    // MARK: - Location Info

    /// 获取位置信息：坐标 → GeoAPI → locationID + 城市名
    private func fetchLocationInfo() async -> (id: String, city: String, district: String)? {
        // 如果有缓存，直接使用
        if let cached = cachedLocationInfo {
            print("[Location] Using cached: \(cached.city) \(cached.district) (ID: \(cached.id))")
            return cached
        }

        // 获取当前位置坐标
        guard let location = await getCurrentLocation() else {
            print("[Location] No location available, using default")
            return (id: config.locationID, city: config.cityName, district: config.districtName)
        }

        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        print("[Location] Got coordinates: \(lat), \(lon)")

        // 使用 GeoAPI 查询 locationID
        guard let geoResult = await queryGeoAPI(lat: lat, lon: lon) else {
            print("[Location] GeoAPI failed, using default")
            return (id: config.locationID, city: config.cityName, district: config.districtName)
        }

        // 缓存结果
        cachedLocationInfo = geoResult
        return geoResult
    }

    /// 查询 GeoAPI 获取 locationID 和城市名
    private func queryGeoAPI(lat: Double, lon: Double) async -> (id: String, city: String, district: String)? {
        let urlString = "\(config.baseURL)/geo/v2/city/lookup?location=\(lon),\(lat)"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(config.apiKey, forHTTPHeaderField: "X-QW-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await networkClient.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("[GeoAPI] HTTP \(httpResponse.statusCode)")
                return nil
            }

            let result = try JSONDecoder().decode(GeoResponse.self, from: data)
            guard result.code == "200", let location = result.location?.first else {
                print("[GeoAPI] Error: \(result.code)")
                return nil
            }

            let id = location.id ?? config.locationID
            let city = location.adm1 ?? ""
            let district = location.name ?? ""
            print("[GeoAPI] Result: id=\(id), city=\(city), district=\(district)")
            return (id: id, city: city, district: district)
        } catch {
            print("[GeoAPI] Error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Weather API

    private func fetchNowWeather(locationID: String) async -> NowWeatherData? {
        let urlString = "\(config.baseURL)/v7/weather/now?location=\(locationID)"
        return await makeRequest(urlString: urlString) { (result: NowResponse) -> NowWeatherData? in
            guard result.code == "200", let now = result.now else { return nil }
            return NowWeatherData(
                temp: Double(now.temp) ?? 0,
                humidity: Int(now.humidity) ?? 0,
                windSpeed: Double(now.windSpeed) ?? 0,
                windDir: now.windDir,
                code: Int(now.icon) ?? 0,
                text: now.text
            )
        }
    }

    private func fetchForecast(locationID: String) async -> ForecastData? {
        let urlString = "\(config.baseURL)/v7/weather/3d?location=\(locationID)"
        return await makeRequest(urlString: urlString) { (result: ForecastResponse) -> ForecastData? in
            guard result.code == "200", let daily = result.daily, let today = daily.first else { return nil }
            return ForecastData(
                maxTemp: Double(today.tempMax) ?? 0,
                minTemp: Double(today.tempMin) ?? 0
            )
        }
    }

    private func makeRequest<T: Codable, R>(urlString: String, handler: (T) -> R?) async -> R? {
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.setValue(config.apiKey, forHTTPHeaderField: "X-QW-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await networkClient.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("[Weather] HTTP \(httpResponse.statusCode)")
                return nil
            }
            let result = try JSONDecoder().decode(T.self, from: data)
            return handler(result)
        } catch {
            print("[Weather] Error: \(error.localizedDescription)")
            return nil
        }
    }

    private func setError(_ message: String) {
        print("[Weather] \(message)")
        weather = WeatherData(
            temperature: 0, temperatureMax: 0, temperatureMin: 0,
            humidity: 0, windSpeed: 0, windDir: "",
            weatherCode: 0, description: "获取失败", iconSystemName: "exclamationmark.triangle",
            cityName: "", districtName: ""
        )
    }

    // MARK: - Location Manager

    private func getCurrentLocation() async -> CLLocation? {
        if let location = currentLocation {
            return location
        }

        guard CLLocationManager.locationServicesEnabled() else {
            print("[Location] Location services not enabled")
            return nil
        }

        let authStatus = locationManager.authorizationStatus
        print("[Location] Authorization status: \(authStatus.rawValue)")

        guard authStatus == .authorized else {
            print("[Location] Not authorized")
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let delegate = LocationDelegate { [weak self] location in
                    if let location = location {
                        self?.currentLocation = location
                    }
                    continuation.resume(returning: location)
                }
                self.locationDelegate = delegate
                self.locationManager.delegate = delegate
                self.locationManager.requestLocation()

                DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
                    if self?.currentLocation == nil {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
}

// MARK: - Location Delegate

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let completion: (CLLocation?) -> Void
    private var hasCompleted = false

    init(completion: @escaping (CLLocation?) -> Void) {
        self.completion = completion
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !hasCompleted else { return }
        hasCompleted = true
        completion(locations.first)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard !hasCompleted else { return }
        hasCompleted = true
        print("[Location] Error: \(error.localizedDescription)")
        completion(nil)
    }
}

// MARK: - QWeather Configuration

struct QWeatherConfig {
    let apiKey: String
    let baseURL: String
    let locationID: String
    let cityName: String
    let districtName: String

    static func fixed(locationID: String, cityName: String, districtName: String) -> QWeatherConfig {
        return QWeatherConfig(
            apiKey: "f878b3cb3f7b447fa2d9053de8982972",
            baseURL: "https://mp3dna5w7u.re.qweatherapi.com",
            locationID: locationID,
            cityName: cityName,
            districtName: districtName
        )
    }

    static func autoDetect(locationID: String) -> QWeatherConfig {
        return QWeatherConfig(
            apiKey: "f878b3cb3f7b447fa2d9053de8982972",
            baseURL: "https://mp3dna5w7u.re.qweatherapi.com",
            locationID: locationID,
            cityName: "",
            districtName: ""
        )
    }

    static let `default` = QWeatherConfig.fixed(
        locationID: "101010100",
        cityName: "北京",
        districtName: "朝阳区"
    )
}

// MARK: - Network Client Protocol

protocol NetworkClientProtocol {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkClientProtocol {}

// MARK: - Response Models

private struct NowResponse: Codable {
    let code: String
    let now: Now?

    struct Now: Codable {
        let temp: String
        let text: String
        let icon: String
        let windDir: String
        let windSpeed: String
        let humidity: String
    }
}

private struct ForecastResponse: Codable {
    let code: String
    let daily: [Daily]?

    struct Daily: Codable {
        let tempMax: String
        let tempMin: String
    }
}

private struct GeoResponse: Codable {
    let code: String
    let location: [GeoLocation]?

    struct GeoLocation: Codable {
        let id: String?        // locationID
        let name: String?      // 地点名称（如"东城"）
        let adm1: String?      // 一级行政区（如"北京市"）
        let adm2: String?      // 二级行政区（如"北京"）
    }
}

private struct NowWeatherData {
    let temp: Double
    let humidity: Int
    let windSpeed: Double
    let windDir: String
    let code: Int
    let text: String
}

private struct ForecastData {
    let maxTemp: Double
    let minTemp: Double
}

// MARK: - Weather Icon Mapper

enum WeatherIconMapper {
    static func iconName(for code: Int) -> String {
        switch code {
        case 100: return "sun.max.fill"
        case 101: return "cloud.sun.fill"
        case 102, 103: return "cloud.sun.fill"
        case 104: return "cloud.fill"
        case 300...399: return "cloud.rain.fill"
        case 400...499: return "cloud.snow.fill"
        case 500...515: return "cloud.fog.fill"
        default: return "cloud.fill"
        }
    }
}

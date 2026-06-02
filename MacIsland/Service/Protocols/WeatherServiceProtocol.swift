//
//  WeatherServiceProtocol.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/1.
//

import Foundation

// MARK: - Weather Data Model

/// 天气数据
struct WeatherData {
    let temperature: Double
    let temperatureMax: Double
    let temperatureMin: Double
    let humidity: Int
    let windSpeed: Double
    let windDir: String
    let weatherCode: Int
    let description: String
    let iconSystemName: String
    let cityName: String      // 城市名（如"北京市"）
    let districtName: String  // 区名（如"朝阳区"）

    static let empty = WeatherData(
        temperature: 0, temperatureMax: 0, temperatureMin: 0,
        humidity: 0, windSpeed: 0, windDir: "",
        weatherCode: 0, description: "加载中...", iconSystemName: "cloud.fill",
        cityName: "", districtName: ""
    )

    /// 显示用的位置字符串（如"北京市 朝阳区"）
    var locationDisplay: String {
        if cityName.isEmpty && districtName.isEmpty { return "" }
        if districtName.isEmpty { return cityName }
        if cityName.isEmpty { return districtName }
        // 去掉"市"后缀避免"北京市"重复显示
        let city = cityName.hasSuffix("市") ? String(cityName.dropLast()) : cityName
        return "\(city) \(districtName)"
    }
}

// MARK: - Weather Service Protocol

/// 天气服务协议
protocol WeatherServiceProtocol: AnyObject {
    var weather: WeatherData { get }
    var isLoading: Bool { get }
    func fetchWeather() async
}

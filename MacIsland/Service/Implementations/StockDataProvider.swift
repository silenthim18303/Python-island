//
//  StockDataProvider.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 数据源类型

/// 股票数据源（全部为 REST API，Swift 直接调用）
enum StockDataSource: String, CaseIterable {
    case sina = "sina"               // 新浪财经 (A股/港股)
    case tencent = "tencent"         // 腾讯财经 (A股/港股)
    case eastmoney = "eastmoney"     // 东方财富 (A股)
    case yahoo = "yahoo"             // Yahoo Finance (美股/港股)
    case alphaVantage = "alpha"      // Alpha Vantage (美股)
    case twelvedata = "twelvedata"   // Twelve Data (通用)

    var displayName: String {
        switch self {
        case .sina: return "新浪财经"
        case .tencent: return "腾讯财经"
        case .eastmoney: return "东方财富"
        case .yahoo: return "Yahoo Finance"
        case .alphaVantage: return "Alpha Vantage"
        case .twelvedata: return "Twelve Data"
        }
    }

    /// 支持的市场
    var supportedMarkets: [StockMarket] {
        switch self {
        case .sina: return [.aShare, .hkStock]
        case .tencent: return [.aShare, .hkStock]
        case .eastmoney: return [.aShare]
        case .yahoo: return [.usStock, .hkStock]
        case .alphaVantage: return [.usStock]
        case .twelvedata: return [.aShare, .usStock, .hkStock]
        }
    }

    /// 是否需要 API Key
    var requiresAPIKey: Bool {
        switch self {
        case .sina, .tencent, .eastmoney: return false
        case .yahoo: return false
        case .alphaVantage, .twelvedata: return true
        }
    }
}

// MARK: - 数据提供者

/// 股票数据提供者 - 全部使用 REST API
final class StockDataProvider {
    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    // MARK: - 获取行情

    /// 获取单只股票行情
    func fetchQuote(symbol: String, market: StockMarket) async throws -> StockQuote {
        switch market {
        case .aShare:
            return try await fetchSinaAStock(symbol: symbol)
        case .usStock:
            return try await fetchYahooUSStock(symbol: symbol)
        case .hkStock:
            return try await fetchSinaHKStock(symbol: symbol)
        }
    }

    /// 批量获取行情
    func fetchBatchQuotes(symbols: [(String, StockMarket)]) async throws -> [StockQuote] {
        // 按市场分组
        var aShareSymbols: [String] = []
        var usSymbols: [String] = []
        var hkSymbols: [String] = []

        for (symbol, market) in symbols {
            switch market {
            case .aShare: aShareSymbols.append(symbol)
            case .usStock: usSymbols.append(symbol)
            case .hkStock: hkSymbols.append(symbol)
            }
        }

        var results: [StockQuote] = []

        // 批量获取 A 股
        if !aShareSymbols.isEmpty {
            let aShareQuotes = try await fetchSinaBatchAStock(symbols: aShareSymbols)
            results.append(contentsOf: aShareQuotes)
        }

        // 批量获取美股
        for symbol in usSymbols {
            let quote = try await fetchYahooUSStock(symbol: symbol)
            results.append(quote)
        }

        // 批量获取港股
        if !hkSymbols.isEmpty {
            let hkQuotes = try await fetchSinaBatchHKStock(symbols: hkSymbols)
            results.append(contentsOf: hkQuotes)
        }

        return results
    }

    // MARK: - 搜索股票

    /// 搜索股票
    func searchStocks(keyword: String, market: StockMarket?) async throws -> [StockItem] {
        // 使用东方财富搜索 API
        return try await searchEastmoney(keyword: keyword)
    }

    // MARK: - K线数据

    /// 获取K线数据
    func fetchKLineData(symbol: String, market: StockMarket, period: KLinePeriod) async throws -> [StockKLinePoint] {
        switch market {
        case .aShare:
            return try await fetchEastmoneyKLine(symbol: symbol, period: period)
        case .usStock:
            return try await fetchYahooKLine(symbol: symbol, period: period)
        case .hkStock:
            return try await fetchEastmoneyKLine(symbol: "hk\(symbol)", period: period)
        }
    }

    /// 获取分时数据
    func fetchTimeLineData(symbol: String, market: StockMarket) async throws -> [StockTimePoint] {
        switch market {
        case .aShare:
            return try await fetchSinaTimeLine(symbol: symbol)
        case .usStock:
            return []
        case .hkStock:
            return try await fetchSinaTimeLine(symbol: "rt_hk\(symbol)")
        }
    }

    // MARK: - 新浪财经 API (A股)

    /// 获取 A 股实时行情
    /// API: https://hq.sinajs.cn/list=sh600519
    private func fetchSinaAStock(symbol: String) async throws -> StockQuote {
        let prefix = symbol.hasPrefix("6") ? "sh" : "sz"
        let urlString = "https://hq.sinajs.cn/list=\(prefix)\(symbol)"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        request.setValue("text/plain", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        // 新浪财经返回 GB2312 编码，先尝试 UTF-8，失败则使用 ISO Latin 1
        guard let response = String(data: data, encoding: .utf8) ??
                String(data: data, encoding: .isoLatin1) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaAStockResponse(response: response, symbol: symbol)
    }

    /// 批量获取 A 股行情
    private func fetchSinaBatchAStock(symbols: [String]) async throws -> [StockQuote] {
        let list = symbols.map { symbol -> String in
            let prefix = symbol.hasPrefix("6") ? "sh" : "sz"
            return "\(prefix)\(symbol)"
        }.joined(separator: ",")

        let urlString = "https://hq.sinajs.cn/list=\(list)"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let response = String(data: data, encoding: .utf8) ??
                String(data: data, encoding: .isoLatin1) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaBatchAStockResponse(response: response, symbols: symbols)
    }

    /// 解析新浪 A 股响应
    /// 格式: var hq_str_sh600519="贵州茅台,1849.00,1847.00,1856.00,1838.00,...";
    private func parseSinaAStockResponse(response: String, symbol: String) throws -> StockQuote {
        let lines = response.components(separatedBy: "\n")

        for line in lines {
            guard line.contains("hq_str_") else { continue }
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 32 else { continue }

            let name = values[0]
            let openPrice = Double(values[1]) ?? 0
            let previousClose = Double(values[2]) ?? 0
            let currentPrice = Double(values[3]) ?? 0
            let highPrice = Double(values[4]) ?? 0
            let lowPrice = Double(values[5]) ?? 0
            let volume = Int64(values[8]) ?? 0
            let turnover = Double(values[9]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            return StockQuote(
                symbol: symbol,
                name: name,
                market: .aShare,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: turnover,
                updatedAt: Date()
            )
        }

        throw StockAPIError.symbolNotFound
    }

    /// 解析新浪批量 A 股响应
    private func parseSinaBatchAStockResponse(response: String, symbols: [String]) throws -> [StockQuote] {
        var results: [StockQuote] = []
        let lines = response.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            guard line.contains("hq_str_"), index < symbols.count else { continue }
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 32 else { continue }

            let name = values[0]
            let openPrice = Double(values[1]) ?? 0
            let previousClose = Double(values[2]) ?? 0
            let currentPrice = Double(values[3]) ?? 0
            let highPrice = Double(values[4]) ?? 0
            let lowPrice = Double(values[5]) ?? 0
            let volume = Int64(values[8]) ?? 0
            let turnover = Double(values[9]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            results.append(StockQuote(
                symbol: symbols[index],
                name: name,
                market: .aShare,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: turnover,
                updatedAt: Date()
            ))
        }

        return results
    }

    // MARK: - 新浪财经 API (港股)

    /// 获取港股实时行情
    private func fetchSinaHKStock(symbol: String) async throws -> StockQuote {
        let urlString = "https://hq.sinajs.cn/list=rt_hk\(symbol)"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let response = String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaHKStockResponse(response: response, symbol: symbol)
    }

    /// 批量获取港股行情
    private func fetchSinaBatchHKStock(symbols: [String]) async throws -> [StockQuote] {
        let list = symbols.map { "rt_hk\($0)" }.joined(separator: ",")
        let urlString = "https://hq.sinajs.cn/list=\(list)"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let response = String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaBatchHKStockResponse(response: response, symbols: symbols)
    }

    /// 解析新浪港股响应
    private func parseSinaHKStockResponse(response: String, symbol: String) throws -> StockQuote {
        let lines = response.components(separatedBy: "\n")

        for line in lines {
            guard line.contains("hq_str_rt_hk") else { continue }
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 15 else { continue }

            let name = values[1]
            let currentPrice = Double(values[6]) ?? 0
            let previousClose = Double(values[3]) ?? 0
            let openPrice = Double(values[2]) ?? 0
            let highPrice = Double(values[4]) ?? 0
            let lowPrice = Double(values[5]) ?? 0
            let volume = Int64(values[12]) ?? 0
            let turnover = Double(values[11]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            return StockQuote(
                symbol: symbol,
                name: name,
                market: .hkStock,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: turnover,
                updatedAt: Date()
            )
        }

        throw StockAPIError.symbolNotFound
    }

    /// 解析新浪批量港股响应
    private func parseSinaBatchHKStockResponse(response: String, symbols: [String]) throws -> [StockQuote] {
        var results: [StockQuote] = []
        let lines = response.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            guard line.contains("hq_str_rt_hk"), index < symbols.count else { continue }
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 15 else { continue }

            let name = values[1]
            let currentPrice = Double(values[6]) ?? 0
            let previousClose = Double(values[3]) ?? 0
            let openPrice = Double(values[2]) ?? 0
            let highPrice = Double(values[4]) ?? 0
            let lowPrice = Double(values[5]) ?? 0
            let volume = Int64(values[12]) ?? 0
            let turnover = Double(values[11]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            results.append(StockQuote(
                symbol: symbols[index],
                name: name,
                market: .hkStock,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: turnover,
                updatedAt: Date()
            ))
        }

        return results
    }

    // MARK: - 新浪财经 API (分时数据)

    /// 获取 A 股分时数据
    private func fetchSinaTimeLine(symbol: String) async throws -> [StockTimePoint] {
        let urlString = "https://quotes.sina.cn/cn/api/jsonp_v2.php/var%20_data=/CN_MarketDataService.getKLineData?symbol=\(symbol)&scale=5&ma=no&datalen=48"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, _) = try await session.data(from: url)
        guard let response = String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        // 解析 JSONP 响应
        guard let jsonStart = response.firstIndex(of: "["),
              let jsonEnd = response.lastIndex(of: "]") else {
            throw StockAPIError.invalidResponse
        }

        let jsonString = String(response[jsonStart...jsonEnd])
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            throw StockAPIError.decodingError(NSError(domain: "", code: 0))
        }

        return jsonArray.compactMap { dict -> StockTimePoint? in
            guard let day = dict["day"] as? String,
                  let closeStr = dict["close"] as? String,
                  let close = Double(closeStr),
                  let volumeStr = dict["volume"] as? String,
                  let volume = Int64(volumeStr) else {
                return nil
            }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let time = formatter.date(from: day) ?? Date()

            return StockTimePoint(time: time, price: close, volume: volume)
        }
    }

    // MARK: - Yahoo Finance API (美股)

    /// 获取美股实时行情
    /// API: https://query1.finance.yahoo.com/v8/finance/chart/AAPL
    private func fetchYahooUSStock(symbol: String) async throws -> StockQuote {
        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let result = chart["result"] as? [[String: Any]],
              let first = result.first,
              let meta = first["meta"] as? [String: Any] else {
            throw StockAPIError.invalidResponse
        }

        let currentPrice = meta["regularMarketPrice"] as? Double ?? 0
        let previousClose = meta["chartPreviousClose"] as? Double ?? 0
        let name = meta["shortName"] as? String ?? symbol

        let changeAmount = currentPrice - previousClose
        let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

        return StockQuote(
            symbol: symbol,
            name: name,
            market: .usStock,
            currentPrice: currentPrice,
            previousClose: previousClose,
            openPrice: meta["regularMarketOpen"] as? Double ?? 0,
            highPrice: meta["regularMarketDayHigh"] as? Double ?? 0,
            lowPrice: meta["regularMarketDayLow"] as? Double ?? 0,
            changeAmount: changeAmount,
            changePercent: changePercent,
            volume: meta["regularMarketVolume"] as? Int64 ?? 0,
            turnover: 0,
            updatedAt: Date()
        )
    }

    /// 获取美股 K 线数据
    private func fetchYahooKLine(symbol: String, period: KLinePeriod) async throws -> [StockKLinePoint] {
        let range: String
        let interval: String

        switch period {
        case .day:
            range = "3mo"
            interval = "1d"
        case .week:
            range = "1y"
            interval = "1wk"
        case .month:
            range = "5y"
            interval = "1mo"
        default:
            range = "5d"
            interval = "5m"
        }

        let urlString = "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=\(interval)&range=\(range)"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, _) = try await session.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let result = chart["result"] as? [[String: Any]],
              let first = result.first,
              let timestamps = first["timestamp"] as? [TimeInterval],
              let indicators = first["indicators"] as? [String: Any],
              let quote = indicators["quote"] as? [[String: Any]],
              let firstQuote = quote.first else {
            throw StockAPIError.invalidResponse
        }

        let opens = firstQuote["open"] as? [Double?] ?? []
        let highs = firstQuote["high"] as? [Double?] ?? []
        let lows = firstQuote["low"] as? [Double?] ?? []
        let closes = firstQuote["close"] as? [Double?] ?? []
        let volumes = firstQuote["volume"] as? [Int64?] ?? []

        var results: [StockKLinePoint] = []
        for i in 0..<timestamps.count {
            let date = Date(timeIntervalSince1970: timestamps[i])
            let open = i < opens.count ? (opens[i] ?? 0) : 0
            let high = i < highs.count ? (highs[i] ?? 0) : 0
            let low = i < lows.count ? (lows[i] ?? 0) : 0
            let close = i < closes.count ? (closes[i] ?? 0) : 0
            let volume = i < volumes.count ? (volumes[i] ?? 0) : 0

            results.append(StockKLinePoint(
                date: date, open: open, high: high,
                low: low, close: close, volume: volume
            ))
        }

        return results
    }

    // MARK: - 东方财富 API (A股搜索)

    /// 搜索股票
    private func searchEastmoney(keyword: String) async throws -> [StockItem] {
        let urlString = "https://searchapi.eastmoney.com/api/suggest/get?input=\(keyword)&type=14&token=D43BF722C8E33BDC906FB84D85E326E8&count=10"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, _) = try await session.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["QuotationCodeTable"] as? [String: Any],
              let data = result["Data"] as? [[String: Any]] else {
            return []
        }

        return data.compactMap { dict -> StockItem? in
            guard let code = dict["Code"] as? String,
                  let name = dict["Name"] as? String else {
                return nil
            }

            let marketStr = dict["MktNum"] as? String ?? ""
            let market: StockMarket
            switch marketStr {
            case "1", "0": market = .aShare
            case "105": market = .usStock
            case "116": market = .hkStock
            default: market = .aShare
            }

            return StockItem(id: code, name: name, market: market, industry: nil)
        }
    }

    // MARK: - 东方财富 API (K线数据)

    /// 获取 K 线数据
    private func fetchEastmoneyKLine(symbol: String, period: KLinePeriod) async throws -> [StockKLinePoint] {
        let secid: String
        if symbol.hasPrefix("hk") {
            secid = "116.\(symbol.replacingOccurrences(of: "hk", with: ""))"
        } else if symbol.hasPrefix("6") {
            secid = "1.\(symbol)"
        } else {
            secid = "0.\(symbol)"
        }

        let klt: String
        switch period {
        case .minute1: klt = "1"
        case .minute5: klt = "5"
        case .minute15: klt = "15"
        case .minute30: klt = "30"
        case .hour1: klt = "60"
        case .day: klt = "101"
        case .week: klt = "102"
        case .month: klt = "103"
        }

        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(secid)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58&klt=\(klt)&fqt=1&end=20500101&lmt=100"

        guard let url = URL(string: urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, _) = try await session.data(from: url)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = json["data"] as? [String: Any],
              let klines = result["klines"] as? [String] else {
            throw StockAPIError.invalidResponse
        }

        let formatter = DateFormatter()
        formatter.dateFormat = period == .day || period == .week || period == .month ? "yyyy-MM-dd" : "yyyy-MM-dd HH:mm"

        return klines.compactMap { line -> StockKLinePoint? in
            let values = line.components(separatedBy: ",")
            guard values.count >= 6 else { return nil }

            let date = formatter.date(from: values[0]) ?? Date()
            let open = Double(values[1]) ?? 0
            let close = Double(values[2]) ?? 0
            let high = Double(values[3]) ?? 0
            let low = Double(values[4]) ?? 0
            let volume = Int64(values[5]) ?? 0

            return StockKLinePoint(date: date, open: open, high: high, low: low, close: close, volume: volume)
        }
    }
}

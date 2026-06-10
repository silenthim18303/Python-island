//
//  StockDataProvider.swift
//  MacIsland
//
//  Created by GeminiMortal on 2026/6/9.
//

import Foundation

// MARK: - 数据源类型

/// 股票数据源
enum StockDataSource: String, CaseIterable {
    case sina = "sina"               // 新浪财经 (A股/美股/港股) — 主数据源
    case eastmoney = "eastmoney"     // 东方财富 (搜索/K线)

    var displayName: String {
        switch self {
        case .sina: return "新浪财经"
        case .eastmoney: return "东方财富"
        }
    }

    /// 支持的市场
    var supportedMarkets: [StockMarket] {
        switch self {
        case .sina: return [.aShare, .usStock, .hkStock]
        case .eastmoney: return [.aShare, .usStock, .hkStock]
        }
    }

    /// 是否需要 API Key
    var requiresAPIKey: Bool {
        return false
    }
}

// MARK: - 数据提供者

/// 股票数据提供者 - 全部使用 REST API
final class StockDataProvider {
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()
    private let decoder = JSONDecoder()

    /// 构建新浪 API 请求（需要 Referer 头）
    private func makeSinaRequest(_ urlString: String) -> URLRequest? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("https://finance.sina.com.cn", forHTTPHeaderField: "Referer")
        request.setValue("text/plain", forHTTPHeaderField: "Accept")
        return request
    }

    /// GB2312/GB18030 编码（新浪 API 使用）
    /// CFStringEncoding value 0x08000100 = kCFStringEncodingGB_2312_8
    private static let gb18030: String.Encoding = {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(0x08000100))
    }()


    /// 检查 HTTP 状态码
    private func checkHTTPStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200...299: return
        case 429: throw StockAPIError.rateLimited
        case 403, 500...599: throw StockAPIError.serverError(http.statusCode)
        default: throw StockAPIError.serverError(http.statusCode)
        }
    }

    // MARK: - 获取行情

    /// 获取单只股票行情
    func fetchQuote(symbol: String, market: StockMarket) async throws -> StockQuote {
        switch market {
        case .aShare:
            return try await fetchSinaAStock(symbol: symbol)
        case .usStock:
            return try await fetchSinaUSStock(symbol: symbol)
        case .hkStock:
            return try await fetchSinaHKStock(symbol: symbol)
        }
    }

    /// 批量获取行情（统一使用新浪财经 API）
    func fetchBatchQuotes(symbols: [(String, StockMarket)]) async throws -> [StockQuote] {
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

        // 批量获取 A 股（独立容错）
        if !aShareSymbols.isEmpty {
            do {
                let quotes = try await fetchSinaBatchAStock(symbols: aShareSymbols)
                results.append(contentsOf: quotes)
            } catch {
                print("[StockProvider] A股获取失败: \(error)")
            }
        }

        // 批量获取美股（独立容错）
        if !usSymbols.isEmpty {
            do {
                let quotes = try await fetchSinaBatchUSStock(symbols: usSymbols)
                results.append(contentsOf: quotes)
            } catch {
                print("[StockProvider] 美股获取失败: \(error)")
            }
        }

        // 批量获取港股（独立容错）
        if !hkSymbols.isEmpty {
            do {
                let quotes = try await fetchSinaBatchHKStock(symbols: hkSymbols)
                results.append(contentsOf: quotes)
            } catch {
                print("[StockProvider] 港股获取失败: \(error)")
            }
        }

        return results
    }

    // MARK: - 搜索股票

    /// 搜索股票
    func searchStocks(keyword: String, market: StockMarket?) async throws -> [StockItem] {
        let results = try await searchEastmoney(keyword: keyword)
        // 客户端过滤市场（东方财富 API 不支持服务端过滤）
        if let market = market {
            return results.filter { $0.market == market }
        }
        return results
    }

    // MARK: - K线数据

    /// 获取K线数据
    func fetchKLineData(symbol: String, market: StockMarket, period: KLinePeriod) async throws -> [StockKLinePoint] {
        switch market {
        case .aShare:
            return try await fetchEastmoneyKLine(symbol: symbol, period: period)
        case .usStock:
            return try await fetchEastmoneyKLine(symbol: symbol, period: period, isUS: true)
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
    private func fetchSinaAStock(symbol: String) async throws -> StockQuote {
        let prefix = StockMarket.aShare.aSharePrefix(for: symbol)
        let urlString = "https://hq.sinajs.cn/list=\(prefix)\(symbol)"

        guard let request = makeSinaRequest(urlString) else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)

        let text = String(data: data, encoding: Self.gb18030) ??
            String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .isoLatin1) ?? ""

        guard !text.isEmpty else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaAStockResponse(response: text, symbol: symbol)
    }

    /// 批量获取 A 股行情
    private func fetchSinaBatchAStock(symbols: [String]) async throws -> [StockQuote] {
        let list = symbols.map { symbol -> String in
            let prefix = StockMarket.aShare.aSharePrefix(for: symbol)
            return "\(prefix)\(symbol)"
        }.joined(separator: ",")

        guard let request = makeSinaRequest("https://hq.sinajs.cn/list=\(list)") else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)

        // 新浪返回 GB2312 编码，优先尝试 GB18030（兼容 GB2312）
        let text = String(data: data, encoding: Self.gb18030) ??
            String(data: data, encoding: .utf8) ??
            String(data: data, encoding: .isoLatin1) ?? ""

        guard !text.isEmpty else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaBatchAStockResponse(response: text, symbols: symbols)
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
        let symbolSet = Set(symbols)

        for line in lines {
            guard line.contains("hq_str_") else { continue }

            // 从响应行中提取代码: var hq_str_sh600519="..."
            guard let codeStart = line.range(of: "hq_str_"),
                  let codeEnd = line.range(of: "=") else { continue }
            let fullCode = String(line[codeStart.upperBound..<codeEnd.lowerBound])
            // 去掉 sh/sz 前缀得到纯代码
            let symbol = String(fullCode.dropFirst(2))
            guard symbolSet.contains(symbol) else { continue }

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
            ))
        }

        return results
    }

    // MARK: - 新浪财经 API (港股)

    /// 获取港股实时行情
    private func fetchSinaHKStock(symbol: String) async throws -> StockQuote {
        guard let request = makeSinaRequest("https://hq.sinajs.cn/list=rt_hk\(symbol)") else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)
        guard let text = String(data: data, encoding: Self.gb18030) ??
                String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaHKStockResponse(response: text, symbol: symbol)
    }

    /// 批量获取港股行情
    private func fetchSinaBatchHKStock(symbols: [String]) async throws -> [StockQuote] {
        let list = symbols.map { "rt_hk\($0)" }.joined(separator: ",")
        guard let request = makeSinaRequest("https://hq.sinajs.cn/list=\(list)") else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)
        guard let text = String(data: data, encoding: Self.gb18030) ??
                String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaBatchHKStockResponse(response: text, symbols: symbols)
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
        let symbolSet = Set(symbols)

        for line in lines {
            guard line.contains("hq_str_rt_hk") else { continue }

            // 从响应行中提取代码: var hq_str_rt_hk00700="..."
            guard let codeStart = line.range(of: "hq_str_rt_hk"),
                  let codeEnd = line.range(of: "=") else { continue }
            let symbol = String(line[codeStart.upperBound..<codeEnd.lowerBound])
            guard symbolSet.contains(symbol) else { continue }

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

    // MARK: - 新浪财经 API (美股)

    /// 获取美股实时行情（新浪 gb_ 前缀）
    private func fetchSinaUSStock(symbol: String) async throws -> StockQuote {
        guard let request = makeSinaRequest("https://hq.sinajs.cn/list=gb_\(symbol.lowercased())") else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)
        guard let text = String(data: data, encoding: Self.gb18030) ??
                String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaUSStockResponse(response: text, symbol: symbol)
    }

    /// 批量获取美股行情
    private func fetchSinaBatchUSStock(symbols: [String]) async throws -> [StockQuote] {
        let list = symbols.map { "gb_\($0.lowercased())" }.joined(separator: ",")
        guard let request = makeSinaRequest("https://hq.sinajs.cn/list=\(list)") else {
            throw StockAPIError.invalidURL
        }

        let (data, response) = try await session.data(for: request)
        try checkHTTPStatus(response)
        guard let text = String(data: data, encoding: Self.gb18030) ??
                String(data: data, encoding: .utf8) else {
            throw StockAPIError.invalidResponse
        }

        return try parseSinaBatchUSStockResponse(response: text, symbols: symbols)
    }

    /// 解析新浪美股响应
    /// 格式: var hq_str_gb_aapl="苹果,301.5400,-1.89,时间,-5.8000,开盘,最高,最低,...";
    private func parseSinaUSStockResponse(response: String, symbol: String) throws -> StockQuote {
        let lines = response.components(separatedBy: "\n")

        for line in lines {
            guard line.contains("hq_str_gb_") else { continue }
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 25 else { continue }

            let name = values[0]
            let currentPrice = Double(values[1]) ?? 0
            // values[2] = 涨跌幅(%)
            // values[4] = 涨跌额
            let openPrice = Double(values[5]) ?? 0
            let highPrice = Double(values[6]) ?? 0
            let lowPrice = Double(values[7]) ?? 0
            // values[23] = 昨收价
            let previousClose = Double(values[23]) ?? 0
            let volume = Int64(values[10]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            return StockQuote(
                symbol: symbol,
                name: name,
                market: .usStock,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: 0,
                updatedAt: Date()
            )
        }

        throw StockAPIError.symbolNotFound
    }

    /// 解析新浪批量美股响应
    private func parseSinaBatchUSStockResponse(response: String, symbols: [String]) throws -> [StockQuote] {
        var results: [StockQuote] = []
        let lines = response.components(separatedBy: "\n")
        let symbolSet = Set(symbols.map { $0.lowercased() })

        for line in lines {
            guard line.contains("hq_str_gb_") else { continue }

            guard let codeStart = line.range(of: "hq_str_gb_"),
                  let codeEnd = line.range(of: "=") else { continue }
            let symbol = String(line[codeStart.upperBound..<codeEnd.lowerBound]).uppercased()
            guard symbolSet.contains(symbol.lowercased()) else { continue }

            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }

            let values = components[1].components(separatedBy: ",")
            guard values.count >= 25 else { continue }

            let name = values[0]
            let currentPrice = Double(values[1]) ?? 0
            let openPrice = Double(values[5]) ?? 0
            let highPrice = Double(values[6]) ?? 0
            let lowPrice = Double(values[7]) ?? 0
            let previousClose = Double(values[23]) ?? 0
            let volume = Int64(values[10]) ?? 0

            let changeAmount = currentPrice - previousClose
            let changePercent = previousClose > 0 ? (changeAmount / previousClose) * 100 : 0

            results.append(StockQuote(
                symbol: symbol,
                name: name,
                market: .usStock,
                currentPrice: currentPrice,
                previousClose: previousClose,
                openPrice: openPrice,
                highPrice: highPrice,
                lowPrice: lowPrice,
                changeAmount: changeAmount,
                changePercent: changePercent,
                volume: volume,
                turnover: 0,
                updatedAt: Date()
            ))
        }

        return results
    }


    // MARK: - 东方财富 API (A股搜索)

    /// 搜索股票
    private func searchEastmoney(keyword: String) async throws -> [StockItem] {
        let urlString = "https://searchapi.eastmoney.com/api/suggest/get?input=\(keyword)&type=14&count=10"

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
    private func fetchEastmoneyKLine(symbol: String, period: KLinePeriod, isUS: Bool = false) async throws -> [StockKLinePoint] {
        let secid: String
        if isUS {
            secid = "105.\(symbol)"
        } else if symbol.hasPrefix("hk") {
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

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "yyyyMMdd"
        let endDate = endFormatter.string(from: Date().addingTimeInterval(86400))
        let urlString = "https://push2his.eastmoney.com/api/qt/stock/kline/get?secid=\(secid)&fields1=f1,f2,f3,f4,f5,f6&fields2=f51,f52,f53,f54,f55,f56,f57,f58&klt=\(klt)&fqt=1&end=\(endDate)&lmt=100"

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

# 📈 股票监控功能 - 集成指南

## 文件修改清单

### 1. MacIslandApp.swift
位置: 第 46-58 行（环境对象注入）

```swift
// 在 .environmentObject(serviceContainer.voice) 后面添加：
.environmentObject(serviceContainer.stocks)
```

### 2. SettingsCatalog.swift
位置: 第 57-59 行（SettingsCategory 枚举）

```swift
// 在 case voice 后面添加：
case stock          // 股票

// 在 title 计算属性中添加：
case .stock: return L10n.stockTitle

// 在 systemImage 计算属性中添加：
case .stock: return "chart.line.uptrend.xyaxis"

// 在 keywords 计算属性中添加：
case .stock: return ["股票", "股价", "行情", "stock", "price", "market"]
```

### 3. SettingsView.swift
位置: 第 57-67 行（detailContent）

```swift
// 在 case .voice: VoiceSettingsView() 后面添加：
case .stock:
    StockSettingsView()
```

### 4. InlineSettingsView.swift
位置: categoryContent 函数

```swift
// 在 case .voice: voiceSection 后面添加：
case .stock: stockSection

// 添加 stockSection 属性：
@EnvironmentObject var stockService: StockServiceImpl

private var stockSection: some View {
    StockListView()
}
```

### 5. ExpandedView.swift
位置: 概览 Tab 中

```swift
// 添加股票卡片
StockMiniCard()
    .environmentObject(stockService)
```

### 6. MaxExpandView.swift
位置: 功能列表中

```swift
// 添加股票入口
// 在 Tab 或功能列表中添加股票选项
```

### 7. VoiceServiceProtocol.swift
位置: VoiceCommand 枚举

```swift
// 添加股票语音命令
case stock = "stock"

// 在 triggerWords 中添加：
case .stock: return ["股票", "股价", "stock", "price"]

// 在 displayName 中添加：
case .stock: return L10n.voiceCmdStock

// 在 description 中添加：
case .stock: return L10n.voiceCmdStockDesc
```

### 8. ServiceContainer.swift
位置: handleVoiceCommand 函数

```swift
// 添加股票语音命令处理
case .stock:
    // TODO: 实现股票语音播报
    voice.speak("股票功能开发中")
```

### 9. MacIslandWidgets.swift
位置: WidgetBundle body

```swift
// 在 body 中添加 StockWidget
var body: some Widget {
    WeatherWidget()
    MusicWidget()
    TimerWidget()
    SystemMonitorWidget()
    TodoWidget()
    ClipboardWidget()
    EventWidget()
    StockWidget()  // 添加这行
}
```

### 10. Localization.swift
添加股票相关本地化键：

```swift
// MARK: - Stock
static var stockTitle: String { t("stock_title") }
static var stockSearch: String { t("stock_search") }
static var stockWatchlist: String { t("stock_watchlist") }
static var stockAdd: String { t("stock_add") }
static var stockRemove: String { t("stock_remove") }
static var stockPrice: String { t("stock_price") }
static var stockChange: String { t("stock_change") }
static var stockVolume: String { t("stock_volume") }
static var stockHigh: String { t("stock_high") }
static var stockLow: String { t("stock_low") }
static var stockNoData: String { t("stock_no_data") }

// 中文翻译
"stock_title": "股票",
"stock_search": "搜索股票",
"stock_watchlist": "自选股",
"stock_add": "添加",
"stock_remove": "移除",
"stock_price": "价格",
"stock_change": "涨跌幅",
"stock_volume": "成交量",
"stock_high": "最高",
"stock_low": "最低",
"stock_no_data": "暂无股票数据",

// 英文翻译
"stock_title": "Stock",
"stock_search": "Search Stocks",
"stock_watchlist": "Watchlist",
"stock_add": "Add",
"stock_remove": "Remove",
"stock_price": "Price",
"stock_change": "Change",
"stock_volume": "Volume",
"stock_high": "High",
"stock_low": "Low",
"stock_no_data": "No stock data",

// 日文翻译
"stock_title": "株式",
"stock_search": "株式検索",
"stock_watchlist": "ウォッチリスト",
"stock_add": "追加",
"stock_remove": "削除",
"stock_price": "価格",
"stock_change": "変動",
"stock_volume": "出来高",
"stock_high": "高値",
"stock_low": "安値",
"stock_no_data": "株式データなし",
```

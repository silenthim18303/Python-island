# 📈 股票监控功能 TODO 列表

## 状态说明
- ✅ 已完成
- 🔄 进行中
- ⏳ 待实现
- ❌ 暂不实现

---

## 第一阶段：基础架构 (Day 1-2)

### 数据模型
- ✅ `Model/StockItem.swift` - 股票基础数据模型
- ✅ `Model/StockAlert.swift` - 涨跌提醒模型

### 状态管理
- ✅ `State/StockStore.swift` - 股票数据存储

### 服务层
- ✅ `Service/Protocols/StockServiceProtocol.swift` - 服务协议
- ✅ `Service/Implementations/StockServiceImpl.swift` - 服务实现
- ✅ `Service/Implementations/StockDataProvider.swift` - 数据源抽象层

---

## 第二阶段：API 实现 (Day 3-5)

### 新浪财经 API (A股/港股)
- ⏳ 实现 `fetchSinaQuote()` - 获取实时行情
- ⏳ 实现 `fetchSinaBatchQuotes()` - 批量获取行情
- ⏳ 实现新浪行情数据解析

### Yahoo Finance API (美股)
- ⏳ 实现 `fetchYahooQuote()` - 获取实时行情
- ⏳ 实现 Yahoo 数据解析

### 东方财富 API (备选)
- ⏳ 实现 `fetchEastmoneyQuote()` - 获取实时行情
- ⏳ 实现 K 线数据获取
- ⏳ 实现分时数据获取

### 股票搜索
- ⏳ 实现 `searchStocks()` - 搜索股票
- ⏳ 实现搜索结果缓存

---

## 第三阶段：UI 界面 (Day 6-8)

### 自选股管理
- ⏳ `View/Components/StockListView.swift` - 自选股列表视图
  - TODO: 显示自选股列表
  - TODO: 支持拖拽排序
  - TODO: 左滑删除
  - TODO: 点击查看详情

### 股票详情
- ⏳ `View/Components/StockDetailView.swift` - 股票详情视图
  - TODO: 显示实时行情
  - TODO: 显示 K 线图
  - TODO: 显示分时图
  - TODO: 添加/移除自选按钮

### 股票搜索
- ⏳ `View/Components/StockSearchView.swift` - 股票搜索视图
  - TODO: 搜索输入框
  - TODO: 搜索结果列表
  - TODO: 市场筛选 (A股/美股/港股)
  - TODO: 添加到自选

### 涨跌提醒
- ⏳ `View/Components/StockAlertSettingsView.swift` - 提醒设置视图
  - TODO: 提醒规则列表
  - TODO: 添加提醒规则
  - TODO: 编辑/删除规则
  - TODO: 启用/禁用规则

### 迷你卡片
- ⏳ `View/Components/StockMiniCard.swift` - 股票迷你卡片
  - TODO: 显示股票代码、价格、涨跌幅
  - TODO: 涨跌颜色标识
  - TODO: 点击跳转详情

### 图表视图
- ⏳ `View/Components/StockChartView.swift` - 股票图表视图
  - TODO: 折线图显示
  - TODO: K 线图显示
  - TODO: 分时图显示

### 设置页面
- ⏳ `View/Components/StockSettingsView.swift` - 股票设置页面
  - TODO: 数据源选择
  - TODO: 刷新频率设置
  - TODO: 涨跌颜色设置 (红涨绿跌 / 绿涨红跌)

---

## 第四阶段：集成 (Day 9-10)

### 服务容器集成
- ⏳ 修改 `ServiceContainer.swift`
  - TODO: 添加 `stock: StockServiceImpl` 属性
  - TODO: 初始化股票服务
  - TODO: 在 `startAll()` 中启动自动刷新
  - TODO: 在 `stopAll()` 中停止自动刷新

### 应用入口集成
- ⏳ 修改 `MacIslandApp.swift`
  - TODO: 注入 `stock` 环境对象

### 设置分类集成
- ⏳ 修改 `SettingsCatalog.swift`
  - TODO: 添加 `.stock` 分类
  - TODO: 添加股票相关设置项

### 设置页面集成
- ⏳ 修改 `SettingsView.swift`
  - TODO: 添加股票设置路由

- ⏳ 修改 `InlineSettingsView.swift`
  - TODO: 添加股票设置区域

### 展开态集成
- ⏳ 修改 `ExpandedView.swift`
  - TODO: 在概览 Tab 添加股票卡片

- ⏳ 修改 `MaxExpandView.swift`
  - TODO: 添加股票列表入口

### 语音集成
- ⏳ 修改 `VoiceServiceProtocol.swift`
  - TODO: 添加 `.stock` 语音命令

- ⏳ 修改 `ServiceContainer.swift`
  - TODO: 处理股票语音命令

---

## 第五阶段：小组件 (Day 11-12)

### 股票小组件
- ✅ `MacIslandWidgets/StockWidget.swift` - 股票小组件
  - ✅ 小尺寸显示
  - ✅ 中尺寸显示
  - ✅ 大尺寸显示

### 小组件数据同步
- ⏳ 修改 `WidgetDataManager.swift`
  - TODO: 添加 `updateStocks()` 方法

### 小组件注册
- ⏳ 修改 `MacIslandWidgets.swift`
  - TODO: 注册 StockWidget

### 本地化
- ⏳ 修改 `WidgetLocalization.swift`
  - TODO: 添加股票相关本地化字符串

---

## 第六阶段：本地化 (Day 13)

### 主应用本地化
- ⏳ 修改 `Localization.swift`
  - TODO: 添加股票相关本地化键
  - TODO: 中文翻译
  - TODO: 英文翻译
  - TODO: 日文翻译

---

## 第七阶段：测试与优化 (Day 14-15)

### 功能测试
- ⏳ 测试 A 股行情获取
- ⏳ 测试美股行情获取
- ⏳ 测试港股行情获取
- ⏳ 测试自选股管理
- ⏳ 测试涨跌提醒
- ⏳ 测试小组件显示
- ⏳ 测试语音播报

### 性能优化
- ⏳ 实现请求缓存
- ⏳ 实现批量请求
- ⏳ 优化刷新频率
- ⏳ 减少内存占用

### 错误处理
- ⏳ 网络错误处理
- ⏳ API 限流处理
- ⏳ 数据解析错误处理

---

## 文件清单

### 新增文件 (11 个)

| 文件 | 状态 | 说明 |
|------|------|------|
| `Model/StockItem.swift` | ✅ | 股票数据模型 |
| `Model/StockAlert.swift` | ✅ | 涨跌提醒模型 |
| `State/StockStore.swift` | ✅ | 股票数据存储 |
| `Service/Protocols/StockServiceProtocol.swift` | ✅ | 服务协议 |
| `Service/Implementations/StockServiceImpl.swift` | ✅ | 服务实现 |
| `Service/Implementations/StockDataProvider.swift` | ✅ | 数据源抽象层 |
| `View/Components/StockListView.swift` | ⏳ | 自选股列表 |
| `View/Components/StockDetailView.swift` | ⏳ | 股票详情 |
| `View/Components/StockSearchView.swift` | ⏳ | 股票搜索 |
| `View/Components/StockAlertSettingsView.swift` | ⏳ | 提醒设置 |
| `View/Components/StockMiniCard.swift` | ⏳ | 迷你卡片 |
| `View/Components/StockChartView.swift` | ⏳ | 图表视图 |
| `View/Components/StockSettingsView.swift` | ⏳ | 股票设置 |
| `MacIslandWidgets/StockWidget.swift` | ✅ | 股票小组件 |

### 修改文件 (8 个)

| 文件 | 状态 | 说明 |
|------|------|------|
| `ServiceContainer.swift` | ⏳ | 集成股票服务 |
| `MacIslandApp.swift` | ⏳ | 注入环境对象 |
| `SettingsCatalog.swift` | ⏳ | 添加股票分类 |
| `SettingsView.swift` | ⏳ | 添加股票设置路由 |
| `InlineSettingsView.swift` | ⏳ | 添加股票设置区域 |
| `ExpandedView.swift` | ⏳ | 添加股票卡片 |
| `VoiceServiceProtocol.swift` | ⏳ | 添加股票语音命令 |
| `Localization.swift` | ⏳ | 添加本地化字符串 |

---

## 优先级

1. **高优先级** - API 实现 + 自选股管理 + 小组件
2. **中优先级** - 股票详情 + 图表 + 涨跌提醒
3. **低优先级** - 语音播报 + 设置页面优化

---

## 预计工期

- **总计**: 15 天
- **核心功能**: 10 天
- **优化完善**: 5 天

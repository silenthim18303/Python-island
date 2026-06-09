<div align="center">
  <h1>🏝️ MacIsland</h1>
  <p><strong>macOS 平台的灵动岛（Dynamic Island）桌面应用</strong></p>
  <p>使用 SwiftUI + AppKit 构建，是 <a href="https://github.com/JNTMTMTM">eIsland</a>（Windows / Electron 版）的原生 macOS 实现</p>
</div>

---

## 简介

MacIsland 是一个常驻菜单栏的浮动「灵动岛」应用。它停靠在屏幕顶部刘海区域，根据交互在多种形态间平滑切换，集成了音乐播放控制、同步歌词、实时天气、计时器、剪贴板链接检测、系统监控、壁纸管理、AI 助手、语音控制等功能。

| 平台 | macOS 15.0+ |
| --- | --- |
| 版本 | v2.0.0 |
| 技术栈 | Swift 5.0 / SwiftUI / AppKit / Combine / Speech |
| 依赖 | QWeatherSDK（和风天气，SPM 引入） |
| Bundle ID | `geminimortal.MacIsland` |

## 下载

[📥 下载最新版本 (v2.0.0)](https://github.com/MacIsland/MacIsland/releases/download/v2.0.0/MacIsland_v2.0.0.dmg)

---

## 项目结构

### 📱 主应用 (MacIsland/)

```
MacIsland/
├── MacIslandApp.swift              # 应用入口：MenuBarExtra + AppDelegate（accessory 模式）
├── ContentView.swift               # IslandView 的 SwiftUI 容器
├── Info.plist                      # 应用配置（权限声明、版本信息）
├── MacIsland.entitlements          # 权限声明（网络、定位、关闭沙盒）
```

### 📦 数据模型 (Model/)

| 文件 | 作用 |
|------|------|
| `AlarmItem.swift` | 闹钟数据模型（时间、标签、重复、启用状态） |
| `BookmarkItem.swift` | URL 书签数据模型（标题、URL、图标） |
| `EventItem.swift` | 倒计时/纪念日事件数据模型（名称、日期、类型） |
| `MemoItem.swift` | 便签数据模型（内容、颜色、置顶） |
| `TodoItem.swift` | 待办事项数据模型（标题、优先级、子任务、完成状态） |
| `WallpaperItem.swift` | 壁纸数据模型（本地 + 社区，路径、类型、作者） |

### 🎯 状态层 (State/)

| 文件 | 作用 |
|------|------|
| `AppSettings.swift` | 全局用户偏好设置（动画/快捷键/番茄钟/剪贴板/壁纸/外观/语音，UserDefaults 持久化） |
| `IslandState.swift` | 形态枚举（idle/hover/expanded/maxExpand/notification/lyrics/countdown）+ 动画速度配置 |
| `IslandLayout.swift` | 各形态窗口尺寸/圆角 + 刘海信息（NotchInfo） |
| `IslandStore.swift` | 形态状态机、空闲计时、服务绑定与自动切换 |
| `AlarmStore.swift` | 闹钟 CRUD + UserDefaults 持久化 |
| `BookmarkStore.swift` | 书签 CRUD + UserDefaults 持久化 |
| `EventStore.swift` | 倒计时/纪念日 CRUD + UserDefaults 持久化 |
| `MemoStore.swift` | 便签 CRUD + UserDefaults 持久化 |
| `TodoStore.swift` | 待办事项 CRUD + UserDefaults 持久化 |
| `WallpaperStore.swift` | 壁纸管理（本地/社区下载/上传/删除/私有） |
| `NotificationCenterStore.swift` | 通知中心存储（通知历史、来源过滤、免打扰） |

### 🪟 窗口管理 (Window/)

| 文件 | 作用 |
|------|------|
| `IslandWindowManager.swift` | NSPanel 浮动窗口管理与定位（无边框、状态栏层级、跨 Space） |

### 🎨 视图层 (View/)

#### 核心视图

| 文件 | 作用 |
|------|------|
| `IslandView.swift` | 主视图，绑定服务、同步窗口尺寸 |
| `CapsuleShell.swift` | 胶囊外壳：悬停/点击/背景/形态分发/壁纸渲染 |
| `SettingsView.swift` | 原生偏好设置窗口（NavigationSplitView + 分类侧栏） |
| `Theme.swift` | 设计 token（间距、圆角、字号、透明度、颜色） |

#### 形态视图 (Components/)

| 文件 | 作用 |
|------|------|
| `IdleView.swift` | 空闲态（时间 + 番茄钟 + 歌词滚动 + 倒计时 + 日期） |
| `HoverView.swift` | 悬停态（音乐+天气速览） |
| `ExpandedView.swift` | 展开态（概览/音乐/工具/监控 4 Tab） |
| `MaxExpandView.swift` | 最大展开态（待办/便签/倒数日/闹钟/书签/壁纸/AI/设置/工具） |
| `NotificationView.swift` | 通知态（Toast 通知显示） |
| `LyricsView.swift` | 歌词态（横向绕刘海胶囊单行） |
| `SyncedLyricsView.swift` | 逐行同步歌词渲染 |
| `CountdownCompactView.swift` | 倒计时缩小态 |
| `WideNotchLayout.swift` | 横向绕刘海布局容器 |

#### 功能视图 (Components/)

| 文件 | 作用 |
|------|------|
| `TimerView.swift` | 番茄钟 / 倒计时（展开态内，含 StepperField） |
| `RunCatMonitorView.swift` | 系统监控（CPU/内存/磁盘/电池/网络） |
| `WallpaperView.swift` | 壁纸管理（本地/社区切换 + 详情弹窗） |
| `WallpaperPickerView.swift` | 本地壁纸选择器（拖拽 + 文件选择） |
| `WallpaperCommunityView.swift` | 社区壁纸（浏览/下载/上传/删除/私有） |
| `AIChatView.swift` | AI 对话（Ollama / OpenAI） |
| `AIVoiceChatView.swift` | AI 语音对话（本地 AI + 语音输入/输出） |
| `ToolboxView.swift` | 工具箱（剪贴板历史/编码转换/文件哈希/文件搜索/翻译） |
| `InlineSettingsView.swift` | 灵动岛内嵌设置面板 |
| `TodoListView.swift` | 待办事项列表 |
| `MemoListView.swift` | 便签列表 |
| `EventListView.swift` | 倒数日列表 |
| `AlarmListView.swift` | 闹钟列表 |
| `BookmarkListView.swift` | 书签列表 |
| `ClipboardHistoryView.swift` | 剪贴板历史 |
| `FileHashView.swift` | 文件哈希校验 |
| `FileSearchView.swift` | 本地文件搜索 |
| `EncodingConvertView.swift` | 编码转换 |
| `TranslateView.swift` | 翻译工具 |
| `BreakReminderView.swift` | 休息提醒 |
| `MokugyoView.swift` | 木鱼计数器 |
| `NotificationCenterView.swift` | 通知中心 |
| `VoiceSettingsView.swift` | 语音设置页面 |
| `VoiceConfigView.swift` | TTS/STT 配置页面 |
| `MarqueeText.swift` | 跑马灯滚动文本 |
| `OnboardingView.swift` | 新手引导 |

#### 组件与配置 (Components/)

| 文件 | 作用 |
|------|------|
| `Localization.swift` | 多语言支持（中文/英文/日文，170+ 翻译字符串） |
| `SettingsCatalog.swift` | 设置分类元数据（标题、描述、搜索关键词） |

### ⚙️ 服务层 (Service/)

#### 依赖注入 (DI/)

| 文件 | 作用 |
|------|------|
| `ServiceContainer.swift` | 依赖注入容器，统一生命周期管理 |

#### 协议 (Protocols/)

| 文件 | 作用 |
|------|------|
| `MusicServiceProtocol.swift` | 音乐服务协议（播放/暂停/切歌/音量） |
| `LyricsServiceProtocol.swift` | 歌词服务协议（多源歌词获取） |
| `WeatherServiceProtocol.swift` | 天气服务协议（实时天气/预报） |
| `TimerServiceProtocol.swift` | 计时器服务协议（番茄钟/倒计时）+ PomodoroPhase 枚举 |
| `ClipboardServiceProtocol.swift` | 剪贴板服务协议（URL 检测） |
| `SystemMonitorServiceProtocol.swift` | 系统监控协议（CPU/内存/磁盘/电池/网络） |
| `HotkeyServiceProtocol.swift` | 快捷键服务协议（全局快捷键） |
| `VoiceServiceProtocol.swift` | 语音服务协议 + VoiceCommand/VoiceState 枚举 |

#### 实现 (Implementations/)

| 文件 | 作用 |
|------|------|
| `SystemMusicService.swift` | 系统音乐检测与控制（AppleScript + 分布式通知 + CGWindowList） |
| `LyricsService.swift` | 多源歌词获取（网易云/QQ音乐/酷狗/LRCLIB） |
| `QWeatherService.swift` | 和风天气 + CoreLocation 定位 |
| `TimerService.swift` | 番茄钟 + 倒计时（工作/休息阶段自动推进） |
| `ClipboardService.swift` | 剪贴板 URL 检测（含 SSRF 防护） |
| `SystemMonitorServiceImpl.swift` | CPU/内存/磁盘/电池/网络监控（NWPathMonitor） |
| `HotkeyService.swift` | 全局快捷键（⌥⌘I/P/←/→） |
| `AIService.swift` | AI 对话（Ollama + OpenAI API 兼容） |
| `LocalAIService.swift` | 本地 AI 服务（无需外部 API，内置知识库） |
| `VoiceService.swift` | 语音服务（Speech STT + AVSpeechSynthesizer TTS） |
| `GitHubService.swift` | GitHub API（Device Flow OAuth + 壁纸上传/删除） |
| `WidgetDataManager.swift` | 小组件数据同步（JSON 文件共享） |
| `UpdateManager.swift` | 自动更新（GitHub API 检查新版本） |
| `LaunchAtLoginManager.swift` | 开机自启管理（SMAppService API） |

### 🧩 小组件扩展 (MacIslandWidgets/)

| 文件 | 作用 |
|------|------|
| `MacIslandWidgets.swift` | WidgetBundle 入口（注册 7 个小组件） |
| `WidgetShared.swift` | 共享常量、主题、格式化工具、JSON 数据读取 |
| `WidgetLocalization.swift` | 小组件多语言支持（中/英/日，从共享 UserDefaults 读取语言） |
| `WidgetIntents.swift` | App Intents 交互（待办切换、音乐控制、计时器控制） |
| `WeatherWidget.swift` | 天气小组件（小/中/大，温度范围条+详情卡片） |
| `MusicWidget.swift` | 音乐小组件（小/中/大，播放控制按钮） |
| `TimerWidget.swift` | 计时器小组件（小/中/大，开始/暂停/重置按钮） |
| `SystemMonitorWidget.swift` | 系统监控小组件（小/中/大，圆形仪表盘+详情卡片） |
| `TodoWidget.swift` | 待办小组件（小/中，点击切换完成状态） |
| `ClipboardWidget.swift` | 剪贴板小组件（小/中，复制按钮） |
| `EventWidget.swift` | 倒数日小组件（小/中） |

---

## 架构要点

- **形态状态机**：`IslandStore` 管理 7 种形态，通过 spring 动画切换，并由空闲计时器自动回退。
- **空闲态自适应布局**：无内容时紧凑（时间+日期），有计时器/歌词时自动扩展宽度。
- **缩小态布局**：歌词态与倒计时态采用横向「绕开刘海」布局（由 `WideNotchLayout` 统一封装）。
- **窗口管理**：`IslandWindowManager` 使用 `.borderless + .nonactivatingPanel` 的 `NSPanel`，层级置于 `.statusBar`。
- **输入防误收起**：鼠标点击 + 键盘输入追踪，面板/Sheet/文件选择器打开时均不自动收起。
- **依赖注入**：`ServiceContainer` 集中创建并启停所有服务，通过 `@EnvironmentObject` 注入视图。
- **响应式数据流**：服务以 `ObservableObject` 暴露 `@Published` 状态，`IslandStore` 订阅音乐/计时器状态自动触发形态切换。
- **小组件数据共享**：通过 JSON 文件（`widget_data.json`）在 App Group 容器中共享数据。

---

## 已实现功能

### 灵动岛核心
- ✅ **菜单栏常驻**：`MenuBarExtra` 提供显隐切换与退出；Dock 图标隐藏（accessory 模式）
- ✅ **七态平滑切换**：空闲胶囊、悬停速览、展开面板、最大展开、通知、歌词、倒计时
- ✅ **全局快捷键**：`⌥⌘I` 显隐、`⌥⌘P` 播放/暂停、`⌥⌘←/→` 上/下一首
- ✅ **自动更新**：基于 GitHub API 的应用内检查更新
- ✅ **开机自启**：支持 macOS 13+ SMAppService API

### 音乐与歌词
- ✅ **音乐控制**：基于分布式通知 + CGWindowList + AppleScript 检测系统播放器
- ✅ **同步歌词**：多源歌词获取（网易云/QQ音乐/酷狗/LRCLIB），逐行高亮同步显示

### 天气与计时
- ✅ **实时天气**：和风天气 SDK + CoreLocation 自动定位
- ✅ **计时器**：番茄钟（工作/休息阶段自动推进）与倒计时

### 系统监控
- ✅ **CPU/内存/磁盘/电池/网络**：实时采集与展示

### 桌面小组件
- ✅ **7 种小组件**：天气、音乐、计时器、系统监控、待办、剪贴板、倒数日
- ✅ **3 种尺寸**：小（Small）、中（Medium）、大（Large）
- ✅ **多语言支持**：中文、英文、日文三语言
- ✅ **独立深浅色**：可选择跟随灵动岛、跟随系统、始终浅色或始终深色
- ✅ **小组件交互**：待办切换、音乐控制、计时器控制、剪贴板复制

### AI 助手
- ✅ **AI 对话**：支持 Ollama + OpenAI API 兼容
- ✅ **本地 AI**：无需外部 API 的智能助手（内置知识库）
- ✅ **AI 语音对话**：语音输入 + AI 回复 + 语音播报

### 语音功能
- ✅ **语音输入**：Speech framework 语音转文字
- ✅ **语音控制**：语音指令控制灵动岛（播放/暂停/切歌/展开/收起）
- ✅ **语音播报**：AVSpeechSynthesizer 文字转语音
- ✅ **语音唤醒**：自定义唤醒词
- ✅ **TTS 配置**：语音选择、语速、音调、音量调节
- ✅ **STT 配置**：识别语言切换、连续识别模式

### 壁纸系统
- ✅ **本地壁纸**：文件选择器 + 拖拽添加
- ✅ **壁纸社区**：GitHub 仓库托管，浏览/下载/上传/删除/私有管理
- ✅ **壁纸透明度**：独立于灵动岛透明度的全局壁纸透明度设置

### 工具与效率
- ✅ **剪贴板链接检测**：轮询剪贴板提取 URL，内置黑名单与 SSRF 防护
- ✅ **工具箱**：剪贴板历史、编码转换、文件哈希校验、本地文件搜索、翻译
- ✅ **待办/便签/倒数日/闹钟/书签**：完整 CRUD + UserDefaults 持久化

### 多语言支持
- ✅ **中文**：简体中文完整支持
- ✅ **英文**：English complete support
- ✅ **日文**：日本語完全サポート

---

## 构建与运行

1. 使用 Xcode 打开 `MacIsland.xcodeproj`
2. 依赖通过 Swift Package Manager 自动解析（QWeatherSDK）
3. 构建运行后，可在「设置 → 天气」中填写自己的和风天气 API Key
4. 首次启动需在「系统设置 → 隐私与安全性」中授予**定位**与**辅助功能**权限

> ⚠️ **小组件使用说明**：macOS 要求应用位于 `/Applications` 目录才能正确发现和显示小组件。

## 权限说明

| 权限 | 用途 |
| --- | --- |
| 网络客户端 | 天气、歌词、网页标题抓取、GitHub API、自动更新 |
| 网络服务器 | 设备配对（Bonjour 服务） |
| 定位 | 天气自动定位 |
| 辅助功能 | 全局快捷键监听 |
| 麦克风 | 语音输入 |
| 语音识别 | 语音控制 |

---

## 更新日志

### v2.0.0 (2026-06-09)
- ✅ 自包含 AI 服务（LocalAIService）
- ✅ TTS/STT 配置界面
- ✅ 语音合成配置（语音/语速/音调/音量）
- ✅ 语音识别配置（语言/连续识别）

### v1.11.0 (2026-06-09)
- ✅ AI 语音对话功能
- ✅ 语音输入 + AI 回复 + 语音播报

### v1.10.3 (2026-06-09)
- ✅ 修复语音模块本地化
- ✅ 多语言语音触发词

### v1.10.2 (2026-06-09)
- ✅ 修复语音设置本地化

### v1.10.1 (2026-06-09)
- ✅ 修复语音识别权限问题

### v1.10.0 (2026-06-08)
- ✅ 语音功能实现（STT/TTS/语音控制）

### v1.9.1 (2026-06-08)
- ✅ 小组件交互功能（待办切换、音乐控制、计时器控制）

### v1.9.0 (2026-06-08)
- ✅ 小组件独立深浅色设置

### v1.8.9 (2026-06-08)
- ✅ 小组件语言包系统

### v1.8.8 (2026-06-08)
- ✅ 优化开机自启功能

### v1.8.7 (2026-06-08)
- ✅ 暂时移除手机连接功能

### v1.8.2 (2026-06-08)
- ✅ 优化系统监控中组件布局
- ✅ 新增大组件支持

### v1.7.1 (2026-06-07)
- ✅ 修复小组件数据同步问题
- ✅ 修复壁纸本地化问题

### v1.7.0 (2026-06-07)
- ✅ 快捷键优化
- ✅ 多语言完善

---

## 致谢

- 设计与功能参考自 Windows 版 **eIsland**
- 天气数据由 [和风天气](https://www.qweather.com/) 提供
- 壁纸社区由 [GitHub](https://github.com) 托管，CDN 加速由 [jsDelivr](https://www.jsdelivr.com/) 提供

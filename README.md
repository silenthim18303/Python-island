<div align="center">
  <h1>🏝️ MacIsland</h1>
  <p><strong>macOS 平台的灵动岛（Dynamic Island）桌面应用</strong></p>
  <p>使用 SwiftUI + AppKit 构建，是 <a href="https://github.com/JNTMTMTM">eIsland</a>（Windows / Electron 版）的原生 macOS 实现</p>
</div>

---

## 简介

MacIsland 是一个常驻菜单栏的浮动「灵动岛」应用。它停靠在屏幕顶部刘海区域，根据交互在多种形态间平滑切换，集成了音乐播放控制、同步歌词、实时天气、计时器、剪贴板链接检测、系统监控、壁纸管理与社区分享等功能。

设计参考自 Windows 版的 eIsland，但完全使用原生技术栈重写，借助 `NSPanel` 实现无边框悬浮窗口，借助 SwiftUI 实现状态驱动的形态动画。

| 平台 | macOS 15.0+ |
| --- | --- |
| 版本 | v1.8.5 |
| 技术栈 | Swift 5.0 / SwiftUI / AppKit / Combine / MultipeerConnectivity |
| 依赖 | QWeatherSDK（和风天气，SPM 引入） |
| Bundle ID | `geminimortal.MacIsland` |

## 下载

[📥 下载最新版本 (v1.8.5)](https://github.com/MacIsland/MacIsland/releases/download/v1.8.5/MacIsland_v1.8.5.dmg)

## 项目结构

```
MacIsland/
├── MacIslandApp.swift          # 应用入口：MenuBarExtra + AppDelegate（accessory 模式）
├── ContentView.swift           # IslandView 的 SwiftUI 容器
├── Info.plist / *.entitlements # 权限声明（网络、定位、关闭沙盒）
│
├── Model/                      # 数据模型
│   ├── AlarmItem.swift         # 闹钟数据模型
│   ├── BookmarkItem.swift      # URL 书签数据模型
│   ├── EventItem.swift         # 倒计时/纪念日事件数据模型
│   ├── MemoItem.swift          # 便签数据模型
│   ├── TodoItem.swift          # 待办事项数据模型
│   └── WallpaperItem.swift     # 壁纸数据模型（本地 + 社区）
│
├── State/                      # 状态层
│   ├── IslandState.swift       # 形态枚举 + 动画速度配置
│   ├── IslandLayout.swift      # 各形态窗口尺寸/圆角 + 刘海信息（NotchInfo）
│   ├── IslandStore.swift       # 形态状态机、空闲计时、服务绑定与自动切换
│   ├── AppSettings.swift       # 用户偏好（动画/快捷键/番茄钟/剪贴板/壁纸/外观，UserDefaults 持久化）
│   ├── AlarmStore.swift        # 闹钟 CRUD + 持久化
│   ├── BookmarkStore.swift     # 书签 CRUD + 持久化
│   ├── EventStore.swift        # 倒计时/纪念日 CRUD + 持久化
│   ├── MemoStore.swift         # 便签 CRUD + 持久化
│   ├── TodoStore.swift         # 待办事项 CRUD + 持久化
│   └── WallpaperStore.swift    # 壁纸管理（本地/社区下载/上传/删除/私有）
│
├── Window/
│   └── IslandWindowManager.swift  # NSPanel 浮动窗口管理与定位
│
├── View/                       # 视图层
│   ├── IslandView.swift        # 主视图，绑定服务、同步窗口尺寸
│   ├── CapsuleShell.swift      # 胶囊外壳：悬停/点击/背景/形态分发/壁纸渲染
│   ├── SettingsView.swift      # 原生偏好设置窗口
│   ├── Theme.swift             # 设计 token（间距、圆角、字号、透明度）
│   └── Components/             # 各形态视图
│       ├── IdleView.swift           # 空闲态（时间 + 番茄钟 + 歌词滚动 + 倒计时 + 日期）
│       ├── HoverView.swift          # 悬停态（音乐+天气速览）
│       ├── ExpandedView.swift       # 展开态（概览/音乐/工具/监控 4 Tab）
│       ├── MaxExpandView.swift      # 最大展开态（待办/便签/倒数日/闹钟/书签/壁纸/AI/设置/工具）
│       ├── NotificationView.swift   # 通知态
│       ├── LyricsView.swift         # 歌词态（横向绕刘海胶囊单行）
│       ├── SyncedLyricsView.swift   # 逐行同步歌词渲染
│       ├── CountdownCompactView.swift  # 倒计时缩小态
│       ├── WideNotchLayout.swift    # 横向绕刘海布局容器
│       ├── TimerView.swift          # 番茄钟 / 倒计时（展开态内）
│       ├── RunCatMonitorView.swift  # 系统监控（CPU/内存/储存/电池/网络）
│       ├── WallpaperView.swift      # 壁纸管理（本地/社区切换 + 详情弹窗）
│       ├── WallpaperPickerView.swift # 本地壁纸选择器（拖拽 + 文件选择）
│       ├── WallpaperCommunityView.swift # 社区壁纸（浏览/下载/上传/删除/私有）
│       ├── AIChatView.swift         # AI 对话（Ollama / OpenAI）
│       ├── ToolboxView.swift        # 工具箱（剪贴板历史/编码转换/文件哈希/文件搜索/翻译）
│       ├── InlineSettingsView.swift # 灵动岛内嵌设置面板
│       ├── TodoListView.swift       # 待办事项列表
│       ├── MemoListView.swift       # 便签列表
│       ├── EventListView.swift      # 倒数日列表
│       ├── AlarmListView.swift      # 闹钟列表
│       ├── BookmarkListView.swift   # 书签列表
│       ├── MarqueeText.swift        # 跑马灯滚动文本
│       └── ...
│
└── Service/                    # 服务层（协议 + 实现 + DI）
    ├── DI/ServiceContainer.swift   # 依赖注入容器，统一生命周期
    ├── Protocols/                  # 各服务协议定义
    │   ├── MusicServiceProtocol.swift
    │   ├── LyricsServiceProtocol.swift
    │   ├── WeatherServiceProtocol.swift
    │   ├── TimerServiceProtocol.swift
    │   ├── ClipboardServiceProtocol.swift
    │   ├── SystemMonitorServiceProtocol.swift
    │   └── HotkeyServiceProtocol.swift
    └── Implementations/
        ├── SystemMusicService.swift       # 系统音乐检测与控制（AppleScript + 分布式通知 + CGWindowList）
        ├── LyricsService.swift            # 多源歌词（网易/QQ/酷狗/LRCLIB）
        ├── QWeatherService.swift          # 和风天气 + CoreLocation 定位
        ├── TimerService.swift             # 番茄钟 + 倒计时
        ├── ClipboardService.swift         # 剪贴板 URL 检测（含 SSRF 防护）
        ├── SystemMonitorServiceImpl.swift # CPU/内存/磁盘/电池/网络监控
        ├── HotkeyService.swift            # 全局快捷键（⌥⌘）
        ├── AIService.swift                # AI 对话（Ollama + OpenAI）
        └── GitHubService.swift            # GitHub API（Device Flow OAuth + 壁纸上传/删除）
```

### 架构要点

- **形态状态机**：`IslandStore` 管理 `idle / hover / expanded / maxExpand / notification / lyrics / countdown` 七种形态，通过 spring 动画切换，并由空闲计时器自动回退。
- **空闲态自适应布局**：无内容时紧凑（时间+日期），有计时器/歌词时自动扩展宽度，显示 `时间 · 番茄钟 · 歌词滚动 · 倒计时 · 日期`。
- **缩小态布局**：歌词态与倒计时态采用横向「绕开刘海」布局（由 `WideNotchLayout` 统一封装）；三种缩小态窗口均贴屏幕顶端并下移一个刘海高度。
- **窗口管理**：`IslandWindowManager` 使用 `.borderless + .nonactivatingPanel` 的 `NSPanel`，层级置于 `.statusBar`，可跨 Space、不抢占焦点。
- **输入防误收起**：鼠标点击 + 键盘输入追踪（`lastInteraction`），面板/Sheet/文件选择器打开时均不自动收起。
- **依赖注入**：`ServiceContainer` 集中创建并启停所有服务，通过 `@EnvironmentObject` 注入视图。
- **响应式数据流**：服务以 `ObservableObject` 暴露 `@Published` 状态，`IslandStore` 订阅音乐/计时器状态自动触发形态切换。

## 已实现功能

### 灵动岛核心
- ✅ **菜单栏常驻**：`MenuBarExtra` 提供显隐切换与退出；Dock 图标隐藏（accessory 模式）。
- ✅ **七态平滑切换**：空闲胶囊、悬停速览、展开面板、最大展开、通知、歌词、倒计时，动画速度/弹簧可配置。
- ✅ **全局快捷键**：`⌥⌘I` 显隐、`⌥⌘P` 播放/暂停、`⌥⌘←/→` 上/下一首（需辅助功能权限，含防抖）。

### 音乐与歌词
- ✅ **音乐控制**：基于分布式通知 + `CGWindowList` + AppleScript 检测系统播放器（Apple Music、Spotify、QQ/酷狗/酷我/网易云音乐等），支持播放/暂停/上一首/下一首、进度与音量控制。
- ✅ **同步歌词**：多源歌词获取（网易云 / QQ音乐 / 酷狗 / LRCLIB），按当前播放器智能选源，逐行高亮同步显示。

### 天气与计时
- ✅ **实时天气**：和风天气 SDK + CoreLocation 自动定位（支持指定 locationID），展示实况与预报、温湿度、风向。
- ✅ **计时器**：番茄钟（工作/休息阶段自动推进）与倒计时，到时通过通知态提醒；倒计时进行中自动在缩小态显示。

### 系统监控
- ✅ **CPU/内存/磁盘/电池/网络**：实时采集与展示，含核心数、温度、上下行速度。
- ✅ **桌面小组件**：天气、系统监控、计时器小组件，支持小/中/大三种尺寸。

### 设备配对
- ✅ **多设备支持**：iPhone、iPad、Android、鸿蒙、Mac、Windows 等设备均可配对
- ✅ **多连接方式**：支持 WiFi、蓝牙、热点/WiFi Direct 三种连接方式
- ✅ **通知转发**：接收配对设备的通知并显示在灵动岛
- ✅ **电池状态**：实时显示配对设备的电量和充电状态
- ✅ **Bonjour 发现**：通过 WiFi 自动发现同一网络下的设备
- ✅ **MultipeerConnectivity**：支持蓝牙和 WiFi Direct 自动连接

### 壁纸系统
- ✅ **本地壁纸**：文件选择器 + 拖拽添加，详情弹窗预览+信息+操作。
- ✅ **壁纸透明度**：独立于灵动岛透明度的全局壁纸透明度设置。
- ✅ **自定义缓存路径**：支持自定义壁纸存储位置。
- ✅ **壁纸社区**：GitHub 仓库托管，浏览/下载/上传/删除/私有管理，Device Flow OAuth 授权。
- ✅ **上传优化**：大图片自动压缩至 2048px + JPEG 80% 质量，大幅减少内存和传输量。

### 工具与效率
- ✅ **剪贴板链接检测**：轮询剪贴板提取 URL，抓取网页标题并以通知态展示；内置黑名单与 **SSRF 防护**。
- ✅ **工具箱**：剪贴板历史、编码转换、文件哈希校验、本地文件搜索、翻译。
- ✅ **AI 助手**：支持 Ollama + OpenAI API 兼容，自动端口探测。
- ✅ **待办/便签/倒数日/闹钟/书签**：完整 CRUD + UserDefaults 持久化。

## 构建与运行

1. 使用 Xcode 打开 `MacIsland.xcodeproj`。
2. 依赖通过 Swift Package Manager 自动解析（QWeatherSDK）。
3. 构建运行后，可在「设置 → 天气」中填写自己的和风天气 API Key；留空时使用内置默认 Key（macOS 15.0+）。
4. 首次启动需在「系统设置 → 隐私与安全性」中授予**定位**与**辅助功能**权限。
5. 社区壁纸功能需在设置中配置 GitHub 用户名并完成 Device Flow 授权。

> ⚠️ **小组件使用说明**：macOS 要求应用位于 `/Applications` 目录才能正确发现和显示小组件。下载 DMG 后，请将 MacIsland.app 拖入 `/Applications` 文件夹，然后从该位置启动应用。

## 权限说明

| 权限 | 用途 |
| --- | --- |
| 网络客户端 | 天气、歌词、网页标题抓取、GitHub API |
| 定位 | 天气自动定位 |
| 辅助功能 | 全局快捷键监听 |

> 应用当前关闭了 App Sandbox（`com.apple.security.app-sandbox = false`）以支持系统级播放器检测与全局快捷键。

## 下个版本计划 (v2.0.0)

### 语音 Agent
- 🎤 **语音输入**：支持语音转文字，集成系统 Speech framework
- 🗣️ **语音控制**：语音指令控制灵动岛（播放/暂停/切歌/展开/收起）
- 🤖 **AI 语音对话**：接入 TTS/STT，支持与 AI 助手语音交互
- 🔊 **语音播报**：天气/计时器/通知等信息语音播报
- 🎯 **语音唤醒**：自定义唤醒词，免触控操作

### 其他规划
- 📱 **iPhone 配对**：通过 Local Network 与 iPhone 配对，同步通知/音乐控制
- 📦 **开机自启优化**：更可靠的 Launch Agent 实现
- ✅ **自动更新**：已实现，基于 GitHub API 的应用内检查更新

## 致谢

- 设计与功能参考自 Windows 版 **eIsland**。
- 天气数据由 [和风天气](https://www.qweather.com/) 提供。
- 壁纸社区由 [GitHub](https://github.com) 托管，CDN 加速由 [jsDelivr](https://www.jsdelivr.com/) 提供。

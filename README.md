<div align="center">
  <h1>🏝️ MacIsland</h1>
  <p><strong>macOS 平台的灵动岛（Dynamic Island）桌面应用</strong></p>
  <p>使用 SwiftUI + AppKit 构建，是 <a href="https://github.com/JNTMTMTM">eIsland</a>（Windows / Electron 版）的原生 macOS 实现</p>
</div>

---

## 简介

MacIsland 是一个常驻菜单栏的浮动「灵动岛」应用。它停靠在屏幕顶部刘海区域，根据交互在多种形态间平滑切换，集成了音乐播放控制、同步歌词、实时天气、计时器、剪贴板链接检测与系统监控等功能。

设计参考自 Windows 版的 eIsland，但完全使用原生技术栈重写，借助 `NSPanel` 实现无边框悬浮窗口，借助 SwiftUI 实现状态驱动的形态动画。

| 平台 | macOS 26.5+ |
| --- | --- |
| 技术栈 | Swift 5.0 / SwiftUI / AppKit / Combine |
| 依赖 | QWeatherSDK（和风天气，SPM 引入） |
| Bundle ID | `geminimortal.MacIsland` |

## 项目结构

```
MacIsland/
├── MacIslandApp.swift          # 应用入口：MenuBarExtra + AppDelegate（accessory 模式）
├── ContentView.swift           # IslandView 的 SwiftUI 容器
├── Info.plist / *.entitlements # 权限声明（网络、定位、关闭沙盒）
│
├── State/                      # 状态层
│   ├── IslandState.swift       # 形态枚举 + 动画速度配置
│   ├── IslandLayout.swift      # 各形态窗口尺寸/圆角 + 刘海信息（NotchInfo）
│   ├── IslandStore.swift       # 形态状态机、空闲计时、服务绑定与自动切换
│   └── AppSettings.swift       # 用户偏好（动画速度/弹簧/剪贴板开关，UserDefaults 持久化）
│
├── Window/
│   └── IslandWindowManager.swift  # NSPanel 浮动窗口管理与定位
│
├── View/                       # 视图层
│   ├── IslandView.swift        # 主视图，绑定服务、同步窗口尺寸
│   ├── CapsuleShell.swift      # 胶囊外壳：悬停/点击/背景/形态分发
│   ├── Theme.swift             # 设计 token（间距、圆角、字号、透明度）
│   └── Components/             # 各形态视图
│       ├── IdleView.swift           # 空闲态（紧凑胶囊：时间 + 日期，居中）
│       ├── HoverView.swift          # 悬停态（音乐+天气速览）
│       ├── ExpandedView.swift       # 展开态（概览/音乐/工具/监控 4 Tab）
│       ├── MaxExpandView.swift      # 最大展开态（待办/AI/设置/工具）
│       ├── NotificationView.swift   # 通知态
│       ├── LyricsView.swift         # 歌词态（横向绕刘海胶囊单行）
│       ├── SyncedLyricsView.swift   # 逐行同步歌词渲染
│       ├── CountdownCompactView.swift  # 倒计时缩小态（横向绕刘海：图标 + 剩余时间）
│       ├── WideNotchLayout.swift    # 横向绕刘海布局容器（歌词/倒计时复用）
│       └── TimerView.swift          # 番茄钟 / 倒计时（展开态内）
│
└── Service/                    # 服务层（协议 + 实现 + DI）
    ├── DI/ServiceContainer.swift   # 依赖注入容器，统一生命周期
    ├── Protocols/                  # 各服务协议定义
    └── Implementations/
        ├── SystemMusicService.swift       # 系统音乐检测与控制
        ├── LyricsService.swift            # 多源歌词（网易/QQ/酷狗/LRCLIB）
        ├── QWeatherService.swift          # 和风天气 + CoreLocation 定位
        ├── TimerService.swift             # 番茄钟 + 倒计时
        ├── ClipboardService.swift         # 剪贴板 URL 检测（含 SSRF 防护）
        ├── SystemMonitorServiceImpl.swift # CPU / 内存 / 磁盘监控
        └── HotkeyService.swift            # 全局快捷键（⌥⌘）
```

### 架构要点

- **形态状态机**：`IslandStore` 管理 `idle / hover / expanded / maxExpand / notification / lyrics / countdown` 七种形态，通过 spring 动画切换，并由空闲计时器自动回退。
- **缩小态布局**：空闲态固定紧凑居中（时间+日期）；歌词态与倒计时态采用横向「绕开刘海」布局（左右分列、中间让出物理刘海宽度，由 `WideNotchLayout` 统一封装）；三种缩小态窗口均贴屏幕顶端并下移一个刘海高度，落在刘海正下方。
- **窗口管理**：`IslandWindowManager` 使用 `.borderless + .nonactivatingPanel` 的 `NSPanel`，层级置于 `.statusBar`，可跨 Space、不抢占焦点；根据形态贴合屏幕顶部/刘海。
- **依赖注入**：`ServiceContainer` 集中创建并启停所有服务，通过 `@EnvironmentObject` 注入视图，快捷键回调在容器内连线。
- **响应式数据流**：服务以 `ObservableObject` 暴露 `@Published` 状态，`IslandStore` 订阅音乐状态自动触发歌词态/空闲态切换并按曲目变化拉取歌词；订阅倒计时状态在计时进行时自动进入倒计时缩小态（优先于歌词），结束后回退。

## 已实现功能

- ✅ **菜单栏常驻**：`MenuBarExtra` 提供显隐切换与退出；Dock 图标隐藏（accessory 模式）。
- ✅ **多形态灵动岛**：空闲胶囊、悬停速览、展开面板、最大展开、通知、歌词、倒计时七态平滑切换，动画速度/弹簧可配置。
- ✅ **音乐控制**：基于分布式通知 + `CGWindowList` 兜底检测系统播放器（Apple Music、Spotify、QQ/酷狗/酷我/网易云音乐等），支持播放/暂停/上一首/下一首、进度与音量控制（DEBUG 下可模拟播放）。
- ✅ **同步歌词**：多源歌词获取（网易云 / QQ音乐 / 酷狗 / LRCLIB 兜底），按当前播放器智能选源，逐行高亮同步显示。
- ✅ **实时天气**：和风天气 SDK + CoreLocation 自动定位（支持指定 locationID），展示实况与预报、温湿度、风向，SF Symbols 天气图标映射。
- ✅ **计时器**：番茄钟（工作/休息阶段自动推进）与倒计时，到时通过通知态提醒；倒计时进行中自动在刘海下方以横向缩小态常驻显示剩余时间。
- ✅ **剪贴板链接检测**：轮询剪贴板提取 URL，抓取网页标题并以通知态展示；内置黑名单与 **SSRF 防护**（拦截 localhost / 私有网段 / 云元数据端点）。
- ✅ **系统监控**：CPU、内存、磁盘使用率实时采集与展示。
- ✅ **全局快捷键**：`⌥⌘I` 显隐、`⌥⌘P` 播放/暂停、`⌥⌘←/→` 上/下一首（需辅助功能权限，含防抖）。

## 待完善 / 待开发功能

最大展开态（MaxExpand）的部分 Tab 目前为占位 UI，是后续开发的主要方向；功能对标 eIsland：

- 🚧 **待办事项**：当前为示例静态列表，需接入持久化存储与增删改查。
- 🚧 **AI 助手**：当前为占位说明，计划集成 Claude / DeepSeek 等模型，支持对话、工具调用与语音输入。
- 🚧 **工具箱**：截图、剪贴板历史、格式转换等工具尚未实现（标注「即将推出」）。
- ⬜ **设置面板**：当前仅展示动画速度/弹簧/版本只读项，需补齐可交互的偏好配置与持久化。
- ⬜ **歌词源/天气配置 UI**：服务层已支持多源与手动定位，但缺少用户可视化配置入口。
- ⬜ **开机自启 / 自动更新**：尚未接入。
- ⬜ **对标 eIsland 的更多组件**：番茄钟/倒计时小组件化、URL 收藏、专辑轮播、便签、迷你游戏、邮件、本地文件搜索等（参见 eIsland 的 OverviewTab widgets 与 maxExpand tabs）。
- ⬜ **MediaRemote 限制**：macOS 26+ 下私有 API 被禁用，部分播放器的精确进度依赖通知/窗口兜底，覆盖度有待提升。

## 构建与运行

1. 使用 Xcode 打开 `MacIsland.xcodeproj`。
2. 依赖通过 Swift Package Manager 自动解析（QWeatherSDK）。
3. 在 `QWeatherService` 中配置和风天气 API Key 后构建运行（macOS 26.5+）。
4. 首次启动需在「系统设置 → 隐私与安全性」中授予**定位**与**辅助功能**权限，以启用天气与全局快捷键。

## 权限说明

| 权限 | 用途 |
| --- | --- |
| 网络客户端 | 天气、歌词、网页标题抓取 |
| 定位 | 天气自动定位 |
| 辅助功能 | 全局快捷键监听 |

> 应用当前关闭了 App Sandbox（`com.apple.security.app-sandbox = false`）以支持系统级播放器检测与全局快捷键。

## 致谢

- 设计与功能参考自 Windows 版 **eIsland**。
- 天气数据由 [和风天气](https://www.qweather.com/) 提供。

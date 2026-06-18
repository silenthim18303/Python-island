# PyIsland 2 - 胶囊悬浮小工具

一个基于 PySide6（Qt6）的桌面悬浮胶囊组件，支持可拖动、可点击、自动边缘吸附、空闲自动减淡、以及调用出侧边面板展示 HTML 内容的轻量级桌面工具。

## 功能特性

### 胶囊悬浮窗

- **无边框透明设计**：无边框、透明背景，以胶囊（椭圆）形式悬浮在桌面
- **自由拖动**：按住鼠标左键可自由拖动胶囊
- **自动吸附**：拖到屏幕左边缘后自动半隐藏吸附到左边缘，带动画过渡
- **点击检测**：点击（非拖动）胶囊可打开/关闭侧边面板
- **空闲减淡**：10 秒无操作后胶囊自动减淡（低透明度 + 轻微灰化）
- **延迟加载**：窗口启动先显示，QWebEngineView 后延迟创建，减少启动卡顿
- **自适应分辨率**：根据屏幕分辨率按比例计算尺寸，适配不同显示器

### 侧边面板

- **大窗口展示**：点击胶囊弹出，显示 `dist/index.html` 内容
- **无边框透明**：与胶囊同样的无边框、透明背景、始终置顶
- **自适应位置**：距屏幕左边框留出 5% 宽度的空间，垂直居中显示
- **自适应尺寸**：屏幕宽度的 25% × 屏幕高度的 90%

### 视觉反馈

- **启动闪烁**：胶囊启动完成后会闪烁两次，提示用户它已就绪
- **空闲减淡**：长时间不操作时胶囊会降低存在感，避免干扰
- **平滑过渡**：所有动画过渡均采用缓动曲线，视觉平滑

## 项目结构

```
pyisland2/
├── small_capsule.py    # 主程序：CapsuleWidget（胶囊） + SidePanelWidget（侧边面板）
├── widget.html         # 胶囊外观：渐变蓝色胶囊 + 减淡/闪烁 CSS + JS 接口
├── dist/               # 侧边面板 HTML 内容目录（需自建 index.html）
│   └── index.html      # 侧边面板加载的 HTML 页面
├── pyproject.toml      # 项目依赖配置
├── uv.lock             # 依赖锁定文件
└── README.md           # 本文档
```

## 环境要求

- Python **>= 3.13**
- PySide6 **>= 6.11.1**
- psutil **>= 7.2.2**

## 快速开始

### 1. 安装依赖

```bash
# 方式一：使用 uv（推荐）
uv sync

# 方式二：使用 pip
pip install PySide6>=6.11.1 psutil>=7.2.2
```

### 2. 准备侧边面板内容

创建 `dist/index.html`，作为侧边面板显示的内容。示例：

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>My Panel</title>
    <style>
        body { background: rgba(255,255,255,0.95); border-radius: 12px; }
    </style>
</head>
<body>
    <h1>Hello PyIsland</h1>
</body>
</html>
```

### 3. 运行程序

```bash
python small_capsule.py
```

## 使用说明

| 操作 | 效果 |
|------|------|
| **左键点击** 胶囊 | 打开/关闭侧边面板 |
| **左键拖动** 胶囊 | 自由移动胶囊 |
| **拖动到左边缘后释放** | 自动吸附到左边缘，半隐藏 |
| **10 秒无操作** | 胶囊自动减淡 |
| 点击已显示的侧边面板中的胶囊 | 关闭侧边面板 |

## 核心 API 说明

### `CapsuleWidget`

胶囊悬浮窗主类，继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `initUI()` | 初始化窗口属性和尺寸（轻量级，不含 WebEngine） |
| `_initWebEngine()` | 延迟初始化 WebEngineView，加载 `widget.html` |
| `_initIdleTimer()` / `_resetIdleTimer()` | 10 秒空闲检测计时管理 |
| `toggleSidePanel()` | 点击胶囊时调用，切换侧边面板显示/隐藏 |
| `mousePressEvent` / `mouseMoveEvent` / `mouseReleaseEvent` | 鼠标事件：处理拖动与点击区分 |
| `checkEdgeSnap()` / `autoSnapToEdge()` / `animateToLeftHalf()` | 边缘吸附与动画 |

尺寸参数（可在代码中调整）：

- 高度 = `screen.height // 8`
- 宽度 = `height // 4`

### `SidePanelWidget`

侧边面板窗口类，同样继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `_initWindow()` | 初始化窗口属性、尺寸、位置 |
| `_initWebEngine()` | 初始化 WebEngineView，加载 `dist/index.html` |

尺寸参数：

- 宽度 = `screen.width * 0.25`（25% 屏幕宽度）
- 高度 = `screen.height * 0.9`（90% 屏幕高度）
- 左边距 = `screen.width * 0.01`（距左边框 1% 间距）
- 垂直居中

### `widget.html`

胶囊外观 HTML 文件，包含以下核心部分：

- **CSS**：蓝色渐变 `.capsule-container` 胶囊样式；`.dim` 减淡状态（opacity 0.3 + 饱和度 0.5）；`@keyframes flashHint` 闪烁动画
- **JS 接口**：`window.setCapsuleDim(dimmed)` —— 由 Python 端通过 `runJavaScript` 调用，控制胶囊的减淡状态

## 设计要点

### 1. 点击 vs 拖动的区分

在 `mousePressEvent` 中记录按下时的全局坐标 `self._press_pos`，在 `mouseReleaseEvent` 中与按下位置比较：

- 位移 ≤ 3 像素 → **点击** → 调用 `toggleSidePanel()`
- 位移 > 3 像素 → **拖动** → 调用 `autoSnapToEdge()` 执行吸附

### 2. 延迟加载 QWebEngineView

`QTimer.singleShot(0, self._initWebEngine)` 把 WebEngine 的初始化放到事件循环空闲时执行：

- 窗口先快速显示出来（几乎瞬时）
- 事件循环空闲时再创建 QWebEngineView 并加载 HTML
- 同时配合 **局部导入** `from PySide6.QtWebEngineWidgets import QWebEngineView`，避免模块导入阶段就初始化 QtWebEngine

### 3. 屏幕缩放处理

Qt 的 `QScreen.availableGeometry()` 返回的是**逻辑像素**（已包含系统 DPI 缩放）。

- 直接用 `availableGeometry` 的像素计算，**不需要**再除以 `devicePixelRatio`
- 避免了"逻辑像素 ÷ 缩放比"导致的双重缩放问题

### 4. Python ↔ HTML 双向通信

胶囊的减淡状态由 Python 控制，通过 `web_view.page().runJavaScript()` 调 HTML 中的 `window.setCapsuleDim(true/false)` 函数来切换 CSS 类，实现透明度过渡。

## 自定义调整

### 调整胶囊尺寸

在 `CapsuleWidget.initUI()` 中修改：

```python
target_height = screen_geo.height() // 8   # 调整分母
target_width = target_height // 4           # 调整宽高比
```

### 调整侧边面板尺寸和位置

在 `SidePanelWidget._initWindow()` 中修改：

```python
target_width = int(screen_geo.width() * 0.25)   # 25% 宽度
target_height = int(screen_geo.height() * 0.9)  # 90% 高度
left_margin = int(screen_geo.width() * 0.01)    # 左边距
```

### 调整空闲检测时间

在 `CapsuleWidget._initIdleTimer()` 中修改：

```python
self._idle_timer.setInterval(10000)  # 毫秒
```

### 调整胶囊颜色

在 `widget.html` 的 `.capsule-container` 中修改 `background` 渐变参数。

## 常见问题

**Q: 运行后看不到窗口？**
A: 胶囊在启动时会自动吸附到屏幕左边缘并半隐藏，可能只有一小条露在屏幕外。拖动鼠标在屏幕最左侧尝试捕捉它。

**Q: 点击胶囊没有弹出侧边面板？**
A: 检查 `dist/index.html` 文件是否存在。如果不存在，面板窗口仍然会显示，但内容是空的。

**Q: 窗口尺寸大小和预期不符？**
A: 确保系统 DPI 缩放在正常范围。程序使用 Qt 的逻辑像素自动适配，但某些特殊缩放设置下可能需要微调。

**Q: 在高 DPI 屏幕上胶囊/面板特别小？**
A: 已修复 —— 当前代码使用 Qt 的逻辑像素（`availableGeometry`）直接计算，不再做二次 `÷ devicePixelRatio`。如果你看到异常，请确认使用的是最新版本代码。

## 许可证

本项目仅供学习与个人使用。
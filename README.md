# PyIsland 2 - 胶囊悬浮小工具

一个基于 PySide6（Qt6）的桌面悬浮胶囊组件，支持可拖动、可点击、自动边缘吸附、空闲自动减淡、以及调用出侧边面板展示 HTML 内容的轻量级桌面工具。

## 功能特性

### 胶囊悬浮窗

- **无边框透明设计**：无边框、透明背景，以胶囊（椭圆）形式悬浮在桌面
- **自由拖动**：按住鼠标左键可自由拖动胶囊
- **自动吸附**：拖动释放后自动半隐藏吸附到左边缘，带动画过渡
- **智能检测**：拖到屏幕右半部分（超过 40% 宽度）可打开/关闭侧边面板
- **空闲减淡**：10 秒无操作后胶囊自动减淡（低透明度 + 轻微灰化）
- **延迟加载**：窗口启动先显示，QWebEngineView 后延迟创建，减少启动卡顿
- **自适应分辨率**：根据屏幕分辨率按比例计算尺寸，适配不同显示器
- **启动通知**：启动时弹出系统 Toast 通知，告知用户程序已就绪

### 侧边面板

- **大窗口展示**：点击胶囊弹出，显示 Vue 前端项目
- **无边框透明**：与胶囊同样的无边框、透明背景、始终置顶
- **自适应位置**：距屏幕左边框留出空间，垂直居中显示
- **自适应尺寸**：屏幕宽度的 25% × 屏幕高度的 90%
- **前端引擎**：基于 Vite + Vue 3 构建的现代化前端面板

### 内置功能模块

#### 待办事项
- **可视化任务管理**：在前端面板中添加、完成、删除任务
- **本地持久化**：自动保存到用户目录 `~/.pyisland_side/tasks.json`
- **前后端通信**：通过 QWebChannel 实现 Vue ↔ Python 双向通信

#### 文件中转
- **便捷文件传输**：支持文件选择、拖拽上传和拖出保存
- **中转目录管理**：文件保存在 `~/.pyisland_side/transfer/`
- **自动清理**：可配置自动清理过期文件

### 视觉反馈

- **启动 Toast**：启动完成后弹出系统通知，提示就绪
- **空闲减淡**：长时间不操作时胶囊会降低存在感，避免干扰
- **平滑过渡**：所有动画过渡均采用缓动曲线，视觉平滑

## 项目结构

```
pyisland2/
├── small_capsule.py           # 主程序入口
├── capsule_app/               # 核心 Python 模块
│   ├── __init__.py
│   ├── main.py                # 应用启动与 Toast 通知
│   ├── capsule_window.py      # 胶囊悬浮窗 (CapsuleWidget)
│   ├── side_panel_window.py   # 侧边面板窗口 (SidePanelWidget)
│   └── file_transfer_backend.py  # 文件传输 QWebChannel 后端
├── widget.html                # 胶囊外观：渐变蓝色胶囊
├── pyisland_sideV/            # Vue 3 + Vite 前端项目
│   ├── src/                   # Vue 源码
│   │   ├── features/
│   │   │   ├── todo/          # 待办事项组件
│   │   │   └── transfer/      # 文件传输组件
│   │   └── views/
│   ├── dist/                  # 编译输出，由 Python 加载
│   └── pyside6_backend_guide.md  # 前后端通信规范文档
├── img/                        # 图标资源
│   ├── PyislandLogo.ico
│   ├── PyislandLogo.png
│   └── PyislandLogo.svg
├── requirements.txt            # pip 依赖清单
├── pyproject.toml              # 项目依赖配置（uv）
└── README.md                   # 本文档
```

## 环境要求

- Python **>= 3.13**
- Windows **10 / 11**（Toast 通知和 WebEngine 功能依赖）
- PySide6 **>= 6.11.1**
- psutil **>= 7.2.2**
- win10toast **>= 0.9**
- pywin32 **>= 312**

## 快速开始

### 1. 安装依赖

```bash
# 方式一：使用 pip（推荐，最简单）
pip install -r requirements.txt

# 方式二：使用 uv
uv sync
```

### 2. 构建前端（可选）

`pyisland_sideV/dist/` 目录已包含编译好的前端。如需重新构建：

```bash
cd pyisland_sideV
npm install
npm run build
```

### 3. 运行程序

```bash
python small_capsule.py
```

启动成功后，屏幕左边缘会出现半隐藏的蓝色胶囊，右下角会弹出 Toast 通知提示。

## 使用说明

| 操作 | 效果 |
|------|------|
| **左键点击** 胶囊 | 打开/关闭侧边面板 |
| **左键拖动** 胶囊 | 自由移动胶囊（释放后自动吸附回左边缘） |
| **拖动到屏幕右半部分并释放** | 自动打开/关闭侧边面板 |
| **10 秒无操作** | 胶囊自动减淡 |
| **在侧边面板中编辑待办** | 自动保存到 `~/.pyisland_side/tasks.json` |
| **拖入文件到侧边面板** | 文件保存到 `~/.pyisland_side/transfer/` |

## 数据存储

程序会在用户主目录下创建 `.pyisland_side/` 文件夹用于持久化数据：

```
~/.pyisland_side/
├── tasks.json              # 待办事项数据（JSON）
├── transfer/               # 文件中转目录
│   └── (用户拖入的文件)
└── webengine_profile/      # QWebEngine 缓存目录
```

## 核心 API 说明

### `CapsuleWidget`

胶囊悬浮窗主类，继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `initUI()` | 初始化窗口属性和尺寸（轻量级，不含 WebEngine） |
| `_initWebEngine()` | 延迟初始化 WebEngineView，加载 `widget.html` |
| `_initIdleTimer()` / `_resetIdleTimer()` | 10 秒空闲检测计时管理 |
| `toggle_side_panel()` | 切换侧边面板显示/隐藏 |
| `mousePressEvent` / `mouseMoveEvent` / `mouseReleaseEvent` | 鼠标事件：处理拖动与点击区分 |
| `check_edge_snap()` / `auto_snap_to_edge()` / `animate_to_left_half()` | 边缘吸附与动画 |

尺寸参数（可在代码中调整）：

- 高度 = `screen.height // 8`
- 宽度 = `height // 4`

### `SidePanelWidget`

侧边面板窗口类，同样继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `_initWindow()` | 初始化窗口属性、尺寸、位置 |
| `_init_web_engine()` | 初始化 WebEngineView，加载 Vue 前端 `dist/index.html` |

尺寸参数：

- 宽度 = `screen.width * 0.25`（25% 屏幕宽度）
- 高度 = `screen.height * 0.9`（90% 屏幕高度）
- 左边距 = `screen.width * 0.01`（距左边框 1% 间距）
- 垂直居中

### `TodoBackend`（to_do.py 可选）

待办事项 QWebChannel 后端类，供前端 `backend.saveTasks()` / `backend.loadTasks()` 调用。

信号：

| 信号 | 参数 | 说明 |
|------|------|------|
| `saveTasksResult` | `(bool, str)` | 保存结果：(是否成功, 提示信息) |
| `loadTasksResult` | `(bool, str)` | 加载结果：(是否成功, JSON 字符串) |

槽函数：

| 槽 | 说明 |
|----|------|
| `saveTasks(json_str)` | 接收前端 JSON 字符串，写入 `tasks.json` |
| `loadTasks()` | 读取 `tasks.json`，通过 `loadTasksResult` 返回 JSON |

### `FileTransferBackend`

文件传输 QWebChannel 后端类。

### `widget.html`

胶囊外观 HTML 文件，包含以下核心部分：

- **CSS**：蓝色渐变 `.capsule-container` 胶囊样式；`.dim` 减淡状态（opacity 0.3 + 饱和度 0.5）
- **JS 接口**：`window.setCapsuleDim(dimmed)` —— 由 Python 端通过 `runJavaScript` 调用

## 前后端通信规范

前端（Vue 3）与后端（Python）通过 **QWebChannel** 双向通信，详细规范见 `pyisland_sideV/pyside6_backend_guide.md`。

核心约定：

```javascript
// 前端连接 QWebChannel
new QWebChannel(qt.webChannelTransport, (channel) => {
    const backend = channel.objects.backend;

    // 调用后端方法
    backend.saveTasks(JSON.stringify(tasks));   // 保存待办
    backend.loadTasks();                         // 读取待办

    // 监听后端信号
    backend.saveTasksResult.connect((success, msg) => { ... });
    backend.loadTasksResult.connect((success, json) => { ... });
});
```

## 设计要点

### 1. 点击 vs 拖动的区分

在 `mousePressEvent` 中记录按下时的全局坐标 `self._press_pos`，在 `mouseReleaseEvent` 中与按下位置比较：

- 位移 ≤ 3 像素 → **点击** → 调用 `toggle_side_panel()`
- 位移 > 3 像素 → **拖动** → 调用 `auto_snap_to_edge()` 执行吸附

### 2. 右侧快速呼出

当鼠标释放位置的 x 坐标超过屏幕宽度的 40% 时，自动触发 `toggle_side_panel()`，实现快速呼出/关闭面板。

### 3. 延迟加载 QWebEngineView

`QTimer.singleShot(0, self._initWebEngine)` 把 WebEngine 的初始化放到事件循环空闲时执行：

- 窗口先快速显示出来（几乎瞬时）
- 事件循环空闲时再创建 QWebEngineView 并加载 HTML
- 同时配合 **局部导入**，避免模块导入阶段就初始化 QtWebEngine

### 4. 系统 Toast 通知

使用 `win10toast` 库，通过 Windows 系统 API 推送通知：

- 启动时延迟 500 毫秒发送，避免窗口初始化冲突
- 自动使用 `img/PyislandLogo.ico` 作为通知图标
- `threaded=True` 模式，通知在后台线程，不阻塞主程序

### 5. Python ↔ HTML 双向通信

通过 `QWebChannel` 注册后端对象，前端 JS 直接调用 Python 方法、接收 Python 信号：

- **Python → 前端**：通过 `Signal.emit()` 触发前端 `connect()` 回调
- **前端 → Python**：通过 `channel.objects.backend.methodName()` 调用 Python `@Slot`

### 6. 本地持久化

用户数据统一保存在 `~/.pyisland_side/` 目录下：

- 待办事项：JSON 文件读写，UTF-8 编码
- 文件中转：标准文件系统操作
- WebEngine 配置：独立 profile 目录，避免与系统默认配置冲突

## 自定义调整

### 调整胶囊尺寸

在 `capsule_app/capsule_window.py` 的 `CapsuleWidget.initUI()` 中修改：

```python
target_height = screen_geo.height() // 8   # 调整分母
target_width = target_height // 4           # 调整宽高比
```

### 调整侧边面板尺寸和位置

在 `capsule_app/side_panel_window.py` 的 `SidePanelWidget._init_window()` 中修改：

```python
target_width = int(screen_geo.width() * 0.25)   # 25% 宽度
target_height = int(screen_geo.height() * 0.9)  # 90% 高度
left_margin = int(screen_geo.width() * 0.01)    # 左边距
```

### 调整空闲检测时间

在 `capsule_app/capsule_window.py` 的 `CapsuleWidget._init_idle_timer()` 中修改：

```python
self._idle_timer.setInterval(10000)  # 毫秒
```

### 调整胶囊颜色

在 `widget.html` 的 `.capsule-container` 中修改 `background` 渐变参数。

### 调整 Toast 通知内容

在 `capsule_app/main.py` 的 `run()` 函数中修改：

```python
QTimer.singleShot(500, lambda: _show_toast(
    "通知标题",
    "通知正文"
))
```

## 前端开发指南

### 目录结构

```
pyisland_sideV/
├── src/
│   ├── features/
│   │   ├── todo/            # 待办事项
│   │   └── transfer/        # 文件传输
│   └── views/
├── dist/                    # 编译输出（Python 加载此目录）
└── index.html
```

### 开发流程

```bash
cd pyisland_sideV

# 安装依赖
npm install

# 开发模式（热重载）
npm run dev

# 生产构建（同步到 dist/，Python 自动加载）
npm run build
```

## 常见问题

**Q: 运行后看不到窗口？**
A: 胶囊在启动时会自动吸附到屏幕左边缘并半隐藏，可能只有一小条露在屏幕外。拖动鼠标在屏幕最左侧尝试捕捉它。

**Q: 启动后没有 Toast 通知？**
A: 检查以下几点：
- Windows「设置 → 系统 → 通知」是否已开启
- 是否处于「专注」模式（勿扰会拦截通知）
- `win10toast` 和 `pywin32` 是否已正确安装
- 查看控制台日志：`[Toast] 已发送通知: ...`

**Q: 点击胶囊没有弹出侧边面板？**
A: 检查 `pyisland_sideV/dist/index.html` 是否存在。执行 `cd pyisland_sideV && npm run build` 重新构建前端。

**Q: 待办事项没有保存？**
A: 检查用户目录下的 `.pyisland_side/tasks.json`。程序在写入时会在控制台打印日志。

**Q: 窗口尺寸大小和预期不符？**
A: 程序使用 Qt 的逻辑像素自动适配系统 DPI 缩放，不需要手动处理。

**Q: 图标/通知图标不显示？**
A: `img/PyislandLogo.ico` 必须存在。Win10toast 只接受 `.ico` 格式，`.png` 或 `.svg` 会被自动忽略。

**Q: 在 Win11 上通知不弹出？**
A: Win11 完全兼容。请检查系统通知设置是否已开启，以及是否处于「专注」模式。

## 许可证

本项目仅供学习与个人使用。
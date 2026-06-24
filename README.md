# PyIsland SideV - 侧边栏悬浮软件

一个常驻屏幕边缘的桌面侧边栏工具。屏幕左边缘有一个蓝色胶囊作为入口，点击后在屏幕左侧展开一个宽 25% 的半透明面板，面板内提供待办事项、文件中转等功能。前端使用 Vue 3 + Vite 开发，通过 **QWebChannel** 与 PySide6 后端双向通信。

## 特点

- **胶囊入口**：屏幕左边缘半隐藏的蓝色胶囊，点击展开 / 关闭侧边栏，可自由拖动
- **侧边栏面板**：屏幕左侧 25% 宽度、90% 高度的半透明浮动面板，始终在最前
- **待办事项**：面板内编辑待办，自动持久化到本地
- **文件中转**：从桌面拖文件到面板，或点击面板内的上传区域导入，文件保存在本地中转目录
- **外链跳转**：面板底部的官网 / GitHub / 抖音按钮，会调用系统默认浏览器打开
- **本地持久化**：所有数据保存在 `~/.pyisland_side/` 目录下，独立 profile 不污染系统

## 项目结构

```
pyisland2/
├── small_capsule.py          # 启动入口：`python small_capsule.py`
├── widget.html               # 胶囊外观：蓝色渐变胶囊 + JS 接口
├── capsule_app/              # PySide6 后端核心
│   ├── main.py               # 应用入口：初始化胶囊 + Toast 通知
│   ├── capsule_window.py     # 胶囊悬浮窗 (CapsuleWidget)：拖动、点击、空闲减淡
│   ├── side_panel_window.py  # 侧边栏面板 (SidePanelWidget)：承载 Vue 前端
│   ├── file_transfer_backend.py  # 文件中转 QWebChannel 后端
│   └── browser_backend.py    # 调用系统浏览器 QWebChannel 后端
├── pyisland_sideV/           # Vue 3 + Vite 前端
│   ├── src/
│   │   └── features/
│   │       ├── todo/         # 待办事项组件
│   │       ├── transfer/     # 文件中转组件
│   │       ├── wait/         # 底部外链按钮（官网 / GitHub / 抖音）
│   │       └── about/        # 关于组件
│   └── dist/                 # 编译输出，由 PySide6 加载
├── img/                      # 图标资源 (PyislandLogo.ico / .png / .svg)
├── requirements.txt          # pip 依赖清单
└── pyproject.toml            # 项目依赖配置 (uv)
```

## 环境要求

- Python **>= 3.13**
- Windows **10 / 11**（Toast 通知、`os.startfile`、WebEngine 依赖）
- PySide6 **>= 6.11.1**（含 `QtWebChannel` + `QtWebEngineWidgets`）

## 快速开始

### 1. 安装依赖

```bash
# 方式一：pip（推荐）
pip install -r requirements.txt

# 方式二：uv
uv sync
```

### 2. 构建前端（可选）

`pyisland_sideV/dist/` 已包含编译好的前端。如需重新构建：

```bash
cd pyisland_sideV
npm install
npm run build
```

### 3. 运行程序

```bash
python small_capsule.py
```

启动后：
1. 屏幕左边缘出现一条半隐藏的蓝色胶囊
2. 右下角会弹出 Toast 通知提示"PyIsland SideV 已启动"
3. **点击胶囊** → 展开侧边栏面板
4. 再次点击（或拖到屏幕右半部分释放）→ 关闭侧边栏面板

## 使用说明

| 操作 | 效果 |
|------|------|
| **左键点击** 胶囊 | 打开 / 关闭侧边栏面板 |
| **左键拖动** 胶囊 | 自由移动胶囊（释放后自动吸附回左边缘） |
| **拖动到屏幕右半部分并释放** | 快速呼出 / 关闭侧边栏面板 |
| **10 秒无操作** | 胶囊自动减淡（opacity 降低） |
| 在侧边栏中编辑待办 | 自动保存到 `~/.pyisland_side/tasks.json` |
| 拖入文件到侧边栏的文件中转区 | 文件保存到 `pyisland2/pyisland_fileTransfer/` |
| 点击底部的官网 / GitHub / 抖音按钮 | 调用系统默认浏览器打开链接 |

## 数据存储

程序在本地持久化的数据：

```
~/.pyisland_side/
└── webengine_profile/        # QWebEngine 独立 profile 目录
```

```
pyisland2/pyisland_fileTransfer/   # 文件中转目录（用户拖入 / 上传的文件）
```

## 核心 API 说明

### `CapsuleWidget`（胶囊入口）

悬浮胶囊主类，继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `initUI()` | 初始化窗口属性（无边框、置顶、半透明） |
| `_init_web_engine()` | 延迟初始化 WebEngineView，加载 `widget.html` |
| `_init_idle_timer()` / `_reset_idle_timer()` | 10 秒空闲检测计时管理 |
| `toggle_side_panel()` | 切换侧边栏面板显示 / 隐藏 |
| `mousePressEvent` / `mouseMoveEvent` / `mouseReleaseEvent` | 区分点击与拖动 |
| `auto_snap_to_edge()` | 释放后自动吸附回左边缘 |

尺寸参数（在 `capsule_app/capsule_window.py` 中可调）：

- 高度 = `screen.height // 8`
- 宽度 = `height // 4`

### `SidePanelWidget`（侧边栏面板）

侧边栏面板窗口类，继承自 `QMainWindow`。

关键方法：

| 方法 | 说明 |
|------|------|
| `_init_window()` | 初始化窗口属性、尺寸、位置（屏幕左侧） |
| `_init_web_engine()` | 初始化 WebEngineView，加载 `pyisland_sideV/dist/index.html` |

尺寸参数（在 `capsule_app/side_panel_window.py` 中可调）：

- 宽度 = `screen.width * 0.25`（25% 屏幕宽度）
- 高度 = `screen.height * 0.9`（90% 屏幕高度）
- 左边距 = `screen.width * 0.01`（距左边框 1% 间距）
- 垂直居中

### `FileTransferBackend`（文件中转）

文件中转 QWebChannel 后端。在 `side_panel_window.py` 中注册为 `fileTransferBackend`，前端通过 `channel.objects.fileTransferBackend` 访问。

关键 `@Slot`：

| 槽 | 说明 |
|----|------|
| `listFiles()` → `str`（JSON） | 列出当前中转目录的所有文件 |
| `selectFiles()` → `str`（JSON） | 弹出系统文件对话框，批量导入文件 |
| `importPaths(str)` → `str`（JSON） | 处理原生拖拽进来的本地路径列表 |
| `uploadFile(str)` → `str`（JSON） | 接收前端 base64 上传的文件内容，写入中转目录 |
| `removeFile(str)` → `str`（JSON） | 按文件名删除中转目录中的文件 |
| `clearFiles()` → `str`（JSON） | 清空中转目录 |
| `transferDirectory()` → `str` | 返回中转目录绝对路径 |
| `openTransferDirectory()` → `bool` | 在资源管理器中打开中转目录 |
| `openFileLocation(str)` → `bool` | 在资源管理器中定位到指定文件 |
| `copyFileToClipboard(str)` → `str`（JSON） | 把文件复制到系统剪贴板 |

### `BrowserBackend`（调用系统浏览器）

浏览器跳转 QWebChannel 后端。在 `side_panel_window.py` 中注册为 `browserBackend`。

关键 `@Slot`：

| 槽 | 说明 |
|----|------|
| `openUrl(str)` → `str`（JSON） | 在系统默认浏览器打开 URL，仅允许 `http(s)/mailto/tel` |
| `copyUrl(str)` → `str`（JSON） | 把 URL 复制到系统剪贴板 |

返回 JSON 结构：

```json
{ "ok": true,  "url": "https://example.com" }
{ "ok": false, "error": "only http/https/mailto/tel are allowed" }
```

### `widget.html`（胶囊外观）

胶囊外观 HTML 文件，包含：

- **CSS**：蓝色渐变 `.capsule-container` 胶囊样式；`.dim` 减淡状态（opacity 0.3 + 饱和度 0.5）
- **JS 接口**：`window.setCapsuleDim(dimmed)` —— 由 Python 端通过 `runJavaScript` 调用

## 前后端通信规范

前端（Vue 3）与后端（Python）通过 **QWebChannel** 双向通信。前端在 `index.html` 中已通过 `qrc:///qtwebchannel/qwebchannel.js` 注入桥接脚本。

### 连接方式

```javascript
// 在组件 onMounted 中调用
if (typeof qt !== 'undefined' && qt.webChannelTransport && typeof QWebChannel === 'function') {
  new QWebChannel(qt.webChannelTransport, (channel) => {
    const fileTransfer = channel.objects.fileTransferBackend;
    const browser = channel.objects.browserBackend;

    // 例：打开外链
    browser.openUrl('https://github.com', (reply) => {
      const result = JSON.parse(reply);
      if (!result.ok) console.warn(result.error);
    });

    // 例：请求文件列表
    fileTransfer.listFiles((json) => {
      const files = JSON.parse(json);
    });
  });
}
```

### 已注册对象

| QWebChannel 对象名 | 对应的 Python 类 | 所在文件 |
|--------------------|-------------------|----------|
| `fileTransferBackend` | `FileTransferBackend` | `capsule_app/file_transfer_backend.py` |
| `browserBackend` | `BrowserBackend` | `capsule_app/browser_backend.py` |

## 设计要点

### 1. 点击 vs 拖动的区分

在 `mousePressEvent` 中记录按下时的全局坐标 `self._press_pos`，在 `mouseReleaseEvent` 中比较位移：

- 位移 ≤ 3 像素 → **点击** → 调用 `toggle_side_panel()`
- 位移 > 3 像素 → **拖动** → 调用 `auto_snap_to_edge()`

### 2. 右侧快速呼出

鼠标释放位置 x 超过屏幕宽度的 40% 时，自动触发 `toggle_side_panel()`，实现快速呼出 / 关闭面板。

### 3. 延迟加载 QWebEngineView

`QTimer.singleShot(0, self._init_web_engine)` 把 WebEngine 的初始化放到事件循环空闲时执行：

- 窗口先快速显示（几乎瞬时）
- 事件循环空闲时再创建 QWebEngineView 并加载 HTML
- 配合 **局部导入**，避免模块导入阶段就初始化 QtWebEngine

### 4. 系统 Toast 通知

通过 `win10toast` 调用 Windows 系统 API 推送通知：

- 启动时延迟 500 毫秒发送，避免窗口初始化冲突
- 自动使用 `img/PyislandLogo.ico` 作为通知图标
- `threaded=True` 模式，通知在后台线程，不阻塞主程序

### 5. Python <-> 前端双向通信

通过 `QWebChannel` 在 `SidePanelWidget._init_web_engine()` 中注册后端对象：

```python
self.web_channel = QWebChannel(self.web_view.page())
self.web_channel.registerObject("fileTransferBackend", self.file_transfer_backend)
self.web_channel.registerObject("browserBackend", self.browser_backend)
self.web_view.page().setWebChannel(self.web_channel)
```

- **Python → 前端**：`Signal.emit()` 或 `runJavaScript()`
- **前端 → Python**：`channel.objects.xxx.methodName(arg, callback)`

### 6. 本地持久化与独立 Profile

- 侧边栏 WebEngine 使用独立 profile 目录 `~/.pyisland_side/webengine_profile/`，与系统默认浏览器隔离
- 文件中转目录 `pyisland2/pyisland_fileTransfer/`，方便用户手动管理

## 自定义调整

### 调整胶囊尺寸

在 `capsule_app/capsule_window.py` 的 `CapsuleWidget.initUI()`：

```python
target_height = screen_geo.height() // 8   # 调整分母
target_width = target_height // 4           # 调整宽高比
```

### 调整侧边栏尺寸和位置

在 `capsule_app/side_panel_window.py` 的 `SidePanelWidget._init_window()`：

```python
target_width = int(screen_geo.width() * 0.25)   # 25% 宽度
target_height = int(screen_geo.height() * 0.9)  # 90% 高度
left_margin = int(screen_geo.width() * 0.01)    # 左边距
```

### 调整空闲检测时间

在 `capsule_app/capsule_window.py` 的 `CapsuleWidget._init_idle_timer()`：

```python
self._idle_timer.setInterval(10000)  # 毫秒
```

### 调整胶囊颜色

在 `widget.html` 的 `.capsule-container` 中修改 `background` 渐变参数。

### 调整按钮外链

在 `pyisland_sideV/src/features/wait/wait.vue` 顶部修改：

```javascript
const websiteUrl = 'https://example.com'
const githubUrl = 'https://github.com'
const douyinUrl = 'https://www.douyin.com'
```

## 前端开发指南

### 目录结构

```
pyisland_sideV/
├── src/
│   └── features/
│       ├── todo/         # 待办事项
│       ├── transfer/     # 文件中转
│       ├── wait/         # 底部外链按钮
│       └── about/        # 关于
├── dist/                 # 编译输出（Python 加载此目录）
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
A: 胶囊在启动时会自动吸附到屏幕左边缘并半隐藏，可能只有一小条露在屏幕外。在屏幕最左侧移动鼠标尝试捕捉它。

**Q: 启动后没有 Toast 通知？**
A: 检查以下几点：
- Windows「设置 → 系统 → 通知」是否已开启
- 是否处于「专注」模式（勿扰会拦截通知）
- `win10toast` 是否已正确安装
- 查看控制台日志，确认未抛异常

**Q: 点击胶囊没有弹出侧边栏面板？**
A: 检查 `pyisland_sideV/dist/index.html` 是否存在。执行 `cd pyisland_sideV && npm run build` 重新构建前端。

**Q: 点击底部按钮（官网 / GitHub / 抖音）没反应？**
A: 按钮现在通过 `BrowserBackend.openUrl()` 调用系统默认浏览器。请确认：
1. `capsule_app/browser_backend.py` 存在且已在 `side_panel_window.py` 中注册为 `browserBackend`
2. 系统已设置默认浏览器
3. 在浏览器开发环境下按钮会回退到 `window.open`

**Q: 拖入文件没反应？**
A: 请确认拖入面板的是文件（不是文件夹）。单文件大小不超过 50 MB。

**Q: 窗口尺寸大小和预期不符？**
A: 程序使用 Qt 的逻辑像素自动适配系统 DPI 缩放，不需要手动处理。

**Q: 图标 / 通知图标不显示？**
A: `img/PyislandLogo.ico` 必须存在。Win10toast 只接受 `.ico` 格式，`.png` 或 `.svg` 会被自动忽略。

## 许可证

本项目仅供学习与个人使用。

# PyIsland SideV - 侧边栏悬浮软件

一个常驻屏幕边缘的桌面侧边栏工具。屏幕左边缘有一个蓝色胶囊作为入口，点击后在屏幕左侧展开一个宽 25% 的半透明面板，面板内提供待办事项、文件中转、蓝牙设备检测等功能。前端使用 Vue 3 + Vite 开发，通过 **自定义URL协议拦截** 与 PySide6 后端极简通信，废弃了复杂的QWebChannel方案，稳定性更高。

## 特点

- **胶囊入口**：屏幕左边缘半隐藏的蓝色胶囊，点击展开 / 关闭侧边栏，可自由拖动
- **侧边栏面板**：屏幕左侧 25% 宽度、90% 高度的半透明浮动面板，始终在最前
- **待办事项**：面板内编辑待办，自动持久化到本地
- **文件中转**：从桌面拖文件到面板，或点击面板内的上传区域导入，支持大文件
- **蓝牙设备**：自动扫描系统已连接的蓝牙设备，显示设备名称和电量圆环
- **eIsland联动**：检测系统中是否运行eIsland进程，在about页面显示连接状态
- **系统托盘**：最小化到系统托盘，支持开机自启
- **单实例保护**：通过QLockFile防止多实例启动，重复启动会弹出Toast提示
- **外链跳转**：面板底部的官网 / GitHub / 抖音按钮，会调用系统默认浏览器打开链接
- **本地持久化**：所有数据保存在 `~/.pyisland_side/` 目录下，独立profile不污染系统

## 项目结构

```
pyisland2/
├── small_capsule.py          # 启动入口：`python small_capsule.py`，内置单实例检查
├── widget.html               # 胶囊外观：蓝色渐变胶囊 + JS 接口
├── build_nuitka.bat          # Nuitka打包脚本，编译为Windows单exe
├── capsule_app/              # PySide6 后端核心
│   ├── main.py               # 应用入口：初始化全局资源 + Toast通知公共接口
│   ├── capsule_window.py     # 胶囊悬浮窗(CapsuleWidget)：拖动、点击、空闲减淡 + 系统托盘 + 开机自启
│   ├── side_panel_window.py  # 侧边栏面板(SidePanelWidget)：承载Vue前端，初始化所有后端模块
│   ├── bluetooth_backend.py  # 蓝牙扫描后端：PowerShell获取已连接蓝牙设备，推送给前端
│   └── process_monitor_backend.py # 进程监控后端：检测eIsland进程状态，联动前端显示
├── pyisland_sideV/           # Vue 3 + Vite 前端
│   ├── src/
│   │   └── features/
│   │       ├── todo/         # 待办事项组件
│   │       ├── transfer/     # 文件中转组件
│   │       ├── wait/         # 底部外链按钮（官网 / GitHub / 抖音）
│   │       ├── about/        # 关于组件：显示时间、eIsland连接状态
│   │       └── bluetooth/    # 蓝牙设备列表组件：显示已连接蓝牙设备，电量圆环
│   └── dist/                 # 编译输出，由PySide6加载
├── img/                      # 图标资源 (PyislandLogo.ico / .png / .svg / bluetooth.png)
├── requirements.txt          # pip 依赖清单
└── pyproject.toml            # 项目依赖配置 (uv)
```

## 环境要求

- Python **>= 3.13**
- Windows **10 / 11**（Toast 通知、winrt蓝牙API、WebEngine 依赖）
- PySide6 **>= 6.11.1**（含 QtWebEngineWidgets）
- bleak（可选，用于更精确的蓝牙扫描）

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
5. 系统托盘中会出现程序图标，右键可配置开机自启

## 使用说明

| 操作 | 效果 |
|------|------|
| **左键点击** 胶囊 | 打开 / 关闭侧边栏面板 |
| **左键拖动** 胶囊 | 自由移动胶囊（释放后自动吸附回左边缘） |
| **拖动到屏幕右半部分并释放** | 快速呼出 / 关闭侧边栏面板 |
| **10 秒无操作** | 胶囊自动减淡（opacity 降低） |
| 在侧边栏中编辑待办 | 自动保存到本地localStorage |
| 拖入文件到侧边栏的文件中转区 | 文件信息存入IndexedDB，支持拖拽出到桌面 |
| 点击底部的官网 / GitHub / 抖音按钮 | 调用系统默认浏览器打开链接 |
| 右键系统托盘图标 → 开机自启 | 勾选后开机自动启动程序 |

## 打包部署

使用项目根目录的`build_nuitka.bat`可以打包为独立的Windows exe程序：

```bash
.\build_nuitka.bat
```

打包完成后会在`./Pyisland_sideV.dist/`目录生成可执行文件，支持：
- 开机自启（打包后的exe路径会自动写入注册表）
- 无黑窗运行，完全桌面应用体验
- 整个目录可复制迁移，绿色运行

## 前后端通信规范

前端（Vue 3）与后端（Python）通过 **自定义pyisland://协议拦截** 通信，废弃了老旧的QWebChannel方案。后端通过`runJavaScript`调用前端全局函数推送数据。

### 后端向前端推送数据的格式

```javascript
// 蓝牙设备更新
window.handleBluetoothDevicesUpdate(devices)
// eIsland进程状态更新
window.handleEIslandStatusUpdate(is_running)
// 原生文件拖入
window.handleNativeFileDrop(paths)
```

### 前端向后端请求的格式

```
pyisland://open_file?path=C:/test.txt
pyisland://open_url?url=https://example.com
```

## 数据存储

程序在本地持久化的数据：

```
~/.pyisland_side/
└── webengine_profile/        # QWebEngine 独立 profile 目录
```

前端数据存储：
- 待办事项：localStorage
- 文件中转列表：IndexedDB
- 蓝牙设备：后端主动推送，前端仅展示
```

# Flash Capsule

`Flash Capsule` 是一个基于 `PySide6 + QWebEngine` 的 Windows 桌面悬浮胶囊，用来快速记录闪念、待办和临时素材。

它常驻桌面右上角，默认以小胶囊形态展示；展开后可以输入文本、粘贴图片、拖拽文件，也可以通过离线中文语音识别快速记下一条内容。

## 功能特性

- 悬浮桌面显示，窗口无边框、置顶、可拖拽
- 支持胶囊态 / 展开态切换
- 支持文本待办记录
- 支持粘贴图片或拖拽图片保存到列表
- 支持拖拽本地文件，在列表中保留文件路径
- 点击图片可打开原图，点击文件可在资源管理器中定位
- 支持系统托盘常驻、显示/隐藏、退出
- 支持 Windows 开机自启
- 支持离线中文语音输入
- 自带 `Vosk` 中文小模型，打包时一并带上

## 技术栈

- Python
- PySide6
- Qt WebEngine / WebChannel
- Vosk
- PyAudio
- PyInstaller

## 项目结构

```text
flash_capsule/
├─ app/                    # 桌面窗口、桥接逻辑、原生窗口修复
├─ frontend/               # 胶囊前端页面（HTML / CSS / JS）
├─ img/                    # 图标资源
├─ vosk/                   # 离线语音识别模型与示例脚本
├─ main.py                 # 应用入口
├─ requirements.txt        # Python 依赖
├─ flash_capsule.spec      # PyInstaller 打包配置
└─ build_release.bat       # Windows 打包脚本
```

## 运行环境

建议在 Windows 环境下运行，原因包括：

- 使用了 `winreg` 实现开机自启
- 使用了 `os.startfile` 和 `explorer` 打开文件与目录
- 使用了 Windows DWM 相关窗口修复

语音输入依赖麦克风权限与本地音频设备。

## 安装依赖

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

如果 `PyAudio` 安装失败，通常是本机缺少可用 wheel 或编译环境。优先建议在 Windows 64 位 Python 环境中安装，必要时可先单独解决 `PyAudio` 安装问题，再重新执行依赖安装。

## 启动项目

```powershell
python main.py
```

启动后应用会出现在桌面右上角，并默认常驻系统托盘。

## 使用说明

### 基本操作

- 点击胶囊右侧按钮可展开 / 收起
- 收起状态下可以直接拖拽移动窗口
- 输入文本后按回车或点击“添加”即可保存
- 点击“清空”可清除当前全部记录

### 图片与文件

- 在展开态下，可直接把图片拖进面板
- 支持从剪贴板粘贴图片
- 支持把本地文件拖进面板，列表会记录文件路径
- 点击图片可打开原图
- 点击文件路径可在资源管理器中定位文件

图片大小限制为 `50MB`。

### 语音输入

- 点击“语音输入”按钮开始识别
- 再次点击可停止识别
- 全局快捷键为 `Ctrl + Alt + Y`

语音识别基于本地 `Vosk` 中文模型，不依赖联网。

## 数据存储

应用会把数据写入本机目录：

```text
C:\flash_capsule_temp\
```

其中包括：

- `todos.txt`：待办与记录内容
- `images/`：粘贴或拖入的图片资源

程序会在保存时清理未使用图片，也会定期清理预览临时图片。

## 打包发布

### 方式一：直接使用脚本

```powershell
.\build_release.bat
```

### 方式二：手动执行

```powershell
pyinstaller --noconfirm --clean flash_capsule.spec
```

打包完成后可执行文件位于：

```text
dist\FlashCapsule\FlashCapsule.exe
```

## 打包说明

当前 `flash_capsule.spec` 会一并打入以下资源：

- `frontend/`
- `img/`
- `vosk/`

同时会收集：

- `PySide6.QtWebEngineCore`
- `PySide6.QtWebEngineWidgets`
- `vosk` 动态库
- `pyaudio`

## 适用场景

- 桌面常驻待办记录
- 临时闪念速记
- 截图或图片素材暂存
- 文件路径中转
- 不方便打字时的语音记录

## 已知限制

- 当前主要面向 Windows
- 语音识别效果取决于麦克风质量和环境噪音
- 文件拖拽只记录路径，不复制文件本体
- 图片超过 `50MB` 会被拒绝保存


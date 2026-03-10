### 项目简介
仿苹果灵动岛的桌面小组件，基于 PyQt5 在 Windows 上运行，集成音量/亮度控制、屏幕录制、音乐播放信息、日历、电池与系统状态显示，手势截屏已移除，仅保留可选的手势调试脚本。

### 核心功能
- **灵动岛主界面**：悬浮窗口可展开/收起，显示时间、通知、音乐信息、音量/亮度、电池、电量、日历、录制按钮等（部分功能按依赖可用性自动降级）。
- **屏幕录制**：`mss + opencv + Pillow` 录屏，H.264/MP4 优先，分辨率自适应缩放，文件保存在 `recordings/`。
- **截屏**：手势截屏已移除，如需截图请使用系统快捷键或外部工具。
- **音量控制**：`pycaw + comtypes` 接 Core Audio，可切换静音、调节音量；若接口不可用自动回退模拟按键。
- **亮度控制**：`wmi + pywin32` 调节屏幕亮度，不支持的环境自动降级为模拟值。
- **音乐信息**：`win32gui/win32process/psutil` 读取常见播放器窗口标题（QQ 音乐、网易云、Spotify 等），显示歌曲与歌手。
- **手势识别调试**：独立脚本 `improved_gesture_debug.py`（实时可视化）、`diagnose_gesture_issues.py`（问题诊断）、`enhanced_gesture_optimization.py`（参数优化）。

### 技术栈
- **GUI**：PyQt5（动画、快捷键、窗口拖拽与展开/收起动画）。
- **多媒体**：mss、opencv-python、Pillow（录屏/图像处理）；pycaw/comtypes、win32api/win32con（音量）；wmi/pywin32（亮度）。
- **系统信息**：psutil（电池/进程），win32gui/win32process（窗口信息）。
- **手势**：可选，仅用于独立调试脚本（`mediapipe`、`pyautogui`，默认不安装）。--------------（正在调试中）

### 环境要求
- Windows 10/11，Python 3.9–3.11（32/64 位均可）。
- 摄像头（仅独立手势调试脚本需要；主程序不再依赖手势）。
- 录屏需要安装显卡常用编码器（系统自带 H.264 一般可用）。

### 安装步骤
```bash
# 进入项目目录
cd c:/Users/71750/Downloads/haoxunFloating-Island-main

# 建议启用 UTF-8 以避免 pip 读取中文报错（可选）
set PYTHONUTF8=1  # PowerShell: $env:PYTHONUTF8=1

# 安装依赖
python -m pip install -r requirements.txt
```
依赖说明：
- 亮度控制：`wmi`, `pywin32`
- 音量控制：`comtypes`, `pycaw`
- 手势调试（可选，不默认安装）：`mediapipe`, `pyautogui`
- 录屏：`mss`, `opencv-python`, `Pillow`

### 运行
```bash
python dynamic_island.py
```
- 首次运行会在当前目录创建 `recordings/` 以保存录屏。
- 若某些依赖缺失，对应功能会自动关闭并在控制台提示。

### 手势调试与诊断（可选）
- `improved_gesture_debug.py`：实时可视化手势状态、置信度、抓握进度。
- `diagnose_gesture_issues.py`：诊断抓握/误触发原因，输出统计信息。
- `enhanced_gesture_optimization.py`：返回一组更严格的手势参数，可在自定义逻辑中使用。

### 常见问题
- **pip 解码错误（GBK/CP936）**：先设置 `PYTHONUTF8=1` 再执行安装。
- **缺少 comtypes/pycaw/wmi/pywin32**：确认依赖已安装；若音量仍异常，可将 `volume_utils.py` 中的核心音量接口暂时替换为模拟按键方案测试。
- **录屏或摄像头权限**：确保系统允许应用访问屏幕/摄像头。

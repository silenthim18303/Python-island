# DynamicIsland-imgui-win

一个基于 Dear ImGui 和 Direct3D11 的 Windows 桌面应用，模拟 macOS 上的 "灵动岛"（Dynamic Island）效果并在其中显示系统监控信息。

## 项目地址

本项目是 Python-island 主项目的 imgui 分支：
[https://github.com/Python-island/Python-island/tree/pyisland-imgui](https://github.com/Python-island/Python-island/tree/pyisland-imgui)

## 功能特性

### 核心功能
- **实时系统监控**：
  - CPU / 每核利用率与频率
  - GPU 利用率、显存、温度（支持 NVIDIA/AMD/Intel）
  - 内存使用情况
  - 电池状态与剩余时间
  - 网络带宽统计（可启用）
  - 时间显示（可显示秒）
- **灵动岛界面**：灵动岛的动态交互界面
- **状态栏托盘**：系统托盘图标，提供快捷操作
- **设置系统**：独立的设置窗口，支持分类配置
- **文件中转站(beta)**：支持文件拖放管理（可启用）

### 界面特性
- **透明效果**：半透明背景，融入桌面环境
- **平滑动画**：展开/收起动画效果
- **响应式设计**：根据系统状态自动调整
- **主题**：暗色主题、磨砂玻璃样式、字体、颜色、圆角

## 系统要求

- **操作系统**：Windows 10 或 Windows 11（32/64 位）
- **工具链**：
  - CMake ≥ 3.20
  - Ninja（或其他生成器）
  - MinGW‑w64/GCC（g++）
  - 或 Visual Studio 2019+
- **依赖**：
  - Direct3D 11（系统自带）
  - Windows SDK（包含 DWM、taskschd、Pdh、iphlpapi 等）
  - ImGui（已随仓库提供）
  - 支持 C++17 的编译器

## 构建方法

### 从源码构建

1. **克隆仓库**：
   ```bash
   git clone https://github.com/Python-island/Python-island.git
   cd Python-island
   git checkout pyisland-imgui
   ```

2. **构建项目**：
   ```bash
   mkdir build
   cd build
   cmake -G Ninja -DCMAKE_BUILD_TYPE=Release ..
   cmake --build .
   ```

3. **运行程序**：
   生成的可执行文件 `DynamicIsland.exe` 会包含在 `build/` 目录中。

4. **调试构建**：
   ```bash
   cmake -G Ninja -DCMAKE_BUILD_TYPE=Debug ..
   cmake --build .
   ```

> 注意：你可以从 `CMakeLists.txt` 中注释掉 MinGW 编译器路径，CMake 会自动检测编译器。或者是手动指定编译器路径。


## 使用方法

### 基本操作
- **左键点击**：展开/收起灵动岛
- **右键点击**：打开系统托盘菜单
- **ESC 键**：关闭设置窗口(beta)

### 系统托盘菜单
- **展开面板**：展开灵动岛详细信息
- **设置**：打开设置窗口
- **性能模式**：
  - 省电 (5秒刷新)
  - 平衡 (1秒刷新)
  - 性能 (0.5秒刷新)
- **开机启动**：设置是否随系统启动
- **退出**：退出程序

### 快捷操作
- **Ctrl+Shift+Z**：快速退出程序

## 设置窗口

设置窗口包含以下分类：
- **通用**：开机启动、刷新频率等基本设置
- **外观**：主题、动画效果等界面设置
- **通知**：系统通知配置
- **文件中转站**：文件管理设置（需启用）
- **高级**：调试选项
- **关于**：版本信息和功能列表

## 文件中转站功能(beta)

文件中转站功能默认禁用，可通过修改 `CMakeLists.txt` 中的编译选项启用：

```cmake
# 文件中转站功能开关 (0=禁用, 1=启用)
target_compile_definitions(${PROJECT_NAME} PRIVATE
    USE_FILE_TRANSFER=1
)
```

修改后重新执行 cmake 配置并编译即可生效。

**功能特性**：
- 支持文件拖放到灵动岛
- 支持文件的复制、移动、删除操作
- 支持文件预览（图片、文本）
- 支持文件拖出到其他应用

## 配置文件

程序使用 `config.json`（默认与可执行文件同目录）保存设置。第一次运行会自动创建默认配置，格式如下：

```json
{
  "island": {
    "position": "top-center",
    "offset_x": 0,
    "offset_y": 20,
    "idle_width": 120,
    "idle_height": 40,
    "expanded_width": 380,
    "expanded_height": 450,
    "animation_speed": 12.0,
    "auto_hide_delay": 5.0,
    "show_seconds": false
  },
  "appearance": {
    "theme": "dark",
    "accent_color": "#0078D4",
    "opacity": 0.95,
    "corner_radius": 20.0,
    "shadow_enabled": true,
    "blur_enabled": true,
    "font_size": 16,
    "font_family": "Noto Sans CJK SC",
    "style": "frosted"
  },
  "system": {
    "update_interval_ms": 1000,
    "cpu_enabled": true,
    "gpu_enabled": true,
    "memory_enabled": true,
    "battery_enabled": true,
    "network_enabled": false
  },
  "behavior": {
    "start_with_windows": true,
    "start_minimized": false,
    "silent_mode": false,
    "game_mode_detection": true,
    "notification_enabled": true,
    "max_notifications": 5
  }
}
```

所有字段在代码 `include/config.h` 定义。编辑完成后重启程序或通过 UI 生效。

## 项目结构

```
/
├─ CMakeLists.txt
├─ include/                # 依赖
├─ src/                    # 应用源代码
│   ├ config.*             # 配置管理 (JSON 读写)
│   ├ sysinfo.*            # 系统指标采集 (CPU/GPU/内存/网络)
│   ├ scheduler.*          # 任务计划程序 (开机启动注册)
│   ├ trayicon.*           # 托盘图标与菜单
│   ├ transferstation.*    # 文件中转站 (可选)
│   ├ window.*             # 窗口管理、D3D 设备、WndProc
│   ├ ui.*                 # 灵动岛 UI 绘制 (主界面/设置)
│   ├ Logger.cpp           # 日志系统 (文件 + 控制台)
│   ├ logging.h            # 日志宏 (LOG_INFO 等)
│   ├ mingw_compat.h       # MinGW 头文件兼容层
│   ├ island.h             # 状态机定义 (待整合)
│   └ main.cpp             # 程序入口、初始化、主循环
├─ LICENSE                 # AGPL‑3.0
└─ README.md               
```

### 主要模块
- **config**：管理 config.json，定义配置结构体
- **sysinfo**：后台线程采集系统指标（CPU/GPU/内存/网络/电池）
- **trayicon**：托盘图标与菜单交互封装
- **scheduler**：封装对 Windows 任务计划程序的操作，用于注册开机启动
- **window**：窗口创建、D3D11 设备管理、WndProc 消息处理
- **ui**：灵动岛界面绘制（收起/展开状态、设置窗口）
- **Logger**：线程安全日志系统，支持文件输出和可选控制台输出
- **mingw_compat**：MinGW 下缺失的 Windows COM 接口兼容定义

## 常见问题

### 程序无法启动
- 检查系统是否满足最低要求
- 确保 DirectX 11 已正确安装
- 检查是否有其他程序占用端口

### 灵动岛不显示
- 检查是否被其他窗口遮挡
- 检查系统托盘是否有程序图标
- 尝试重启程序

### 鼠标操作问题
- 灵动岛只在显示区域内捕获鼠标
- 非显示区域的鼠标事件会透传给下层窗口

## 开发说明

- **UI 界面**：依赖 ImGui，渲染使用 imgui_impl_win32.cpp 和 imgui_impl_dx11.cpp
- **日志**：写入 `dynamicisland.log`，可通过取消 `main.cpp` 中的注释启用控制台输出
- **系统监控**：通过 PDH、WMI、NVML 动态链接获取数据
- **任务计划器**：接口封装对 COM 的使用，可注册隐藏启动任务


## 致谢

- **ImGui**：Dear ImGui 库提供了优秀的即时模式 GUI
- **DirectX**：微软的图形 API

---

*如果您喜欢这个项目，请给它一个星标 ⭐ 支持一下！*

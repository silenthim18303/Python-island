# PyIsland（蟒蛇岛）项目文档

## 项目简介

PyIsland（蟒蛇岛）是一个模仿 macOS 灵动岛设计的 Windows 系统工具，提供系统状态监控和快捷操作功能。它在系统托盘区域显示一个可交互的灵动岛界面，实时显示系统状态（如网络、蓝牙、电池），并提供快速访问系统设置的功能。

## 目录结构

```
Python-island/
├── assets/            # 前端资源文件
│   ├── css/           # CSS样式文件
│   │   └── island.css # 灵动岛样式
│   ├── js/            # JavaScript文件
│   │   └── island.js  # 前端交互逻辑
│   ├── public/        # 公共资源
│   │   ├── icon/      # 图标文件
│   │   ├── image/     # 图片资源
│   │   └── svg/       # SVG图标
│   └── island.html    # 灵动岛HTML界面
├── method/            # 后端方法模块
│   ├── __init__.py    # 模块初始化文件
│   ├── getbattery.py  # 电池状态检测
│   ├── getbluetooth.py # 蓝牙状态检测
│   ├── getinternet.py # 网络状态检测
│   ├── getmusicncm.py # 音乐控制（网易云音乐）
│   └── sendtoast.py   # Windows通知发送
├── .gitignore         # Git忽略文件
├── PyIsland.spec      # PyInstaller打包配置
├── __init__.py        # 项目初始化文件
├── build.py           # 构建脚本
├── pyisland2.py       # 主应用程序
└── requirements.txt   # 依赖项列表
```

## 核心功能

1. **系统状态监控**
   - 网络连接状态
   - 蓝牙设备连接状态
   - 电池电量和充电状态
   - 系统时间显示

2. **快捷操作**
   - 点击图标打开相应的系统设置
   - 支持鼠标穿透模式
   - 系统托盘菜单

3. **视觉效果**
   - 平滑的展开/收起动画
   - 状态变化通知
   - 半透明效果

4. **系统集成**
   - Windows通知支持
   - 系统托盘图标
   - 开机启动选项

## 技术栈

- **前端**：HTML5, CSS3, JavaScript
- **后端**：Python 3.13
- **GUI框架**：PySide6（Qt for Python）
- **系统集成**：Windows API
- **打包工具**：PyInstaller

## 安装和运行

### 环境要求

- Windows 10/11
- Python 3.13+
- pip

### 安装依赖

```bash
pip install -r requirements.txt
```

### 运行应用

```bash
python pyisland2.py
```

## 代码结构

### 主应用程序（pyisland2.py）

主应用程序负责：
- 初始化Qt应用
- 创建和管理灵动岛窗口
- 处理系统托盘
- 启动后台状态检测线程
- 与前端JavaScript通信

### 前端界面（assets/island.html, assets/js/island.js）

前端界面负责：
- 显示系统状态
- 处理用户交互
- 显示通知
- 实现动画效果

### 状态检测模块（method/）

- **getbattery.py**：检测电池状态和电量
- **getinternet.py**：检测网络连接状态
- **getbluetooth.py**：检测蓝牙设备连接状态
- **sendtoast.py**：发送Windows系统通知

## 主要模块说明

### PyIslandBridge 类

负责与前端JavaScript通信的桥接类，提供：
- `openWindowsSettings(setting_type)`：打开指定类型的系统设置

### StatusWorker 类

后台状态检测线程，定期检测：
- 电池状态和电量
- 网络连接状态
- 蓝牙设备连接状态

### IslandWindow 类

主窗口类，负责：
- 创建和管理灵动岛窗口
- 处理窗口动画
- 响应鼠标事件
- 管理系统托盘

### SettingsOpener 类

系统设置打开器，提供：
- 打开各种Windows系统设置的方法
- 支持多种设置类型

## 打包方法

使用PyInstaller打包应用：

1. 确保所有依赖已安装
2. 运行打包命令：

```bash
pyinstaller PyIsland.spec
```

打包完成后，可执行文件会在 `dist` 目录中生成。

## 未来扩展

1. **功能扩展**
   - 支持更多系统设置的快速访问
   - 集成更多系统状态监控（如CPU、内存使用）
   - 添加自定义主题支持

2. **性能优化**
   - 减少资源占用
   - 优化动画效果
   - 提高响应速度

3. **跨平台支持**
   - 考虑支持其他操作系统
   - 适配不同屏幕尺寸和分辨率

4. **用户体验**
   - 添加更多个性化选项
   - 支持拖拽调整位置
   - 实现更多交互效果

## 注意事项

- 本应用需要管理员权限才能正常运行
- 部分功能可能需要特定的Windows版本支持
- 蓝牙设备检测需要相应的系统服务支持

## 故障排除

- **应用无法启动**：检查是否有管理员权限
- **状态显示不正确**：检查相应的系统服务是否正常运行
- **设置无法打开**：检查Windows版本是否支持相应的设置页面
- **通知不显示**：检查系统通知设置是否允许应用发送通知

## 贡献

欢迎提交Issue和Pull Request，共同改进PyIsland项目。
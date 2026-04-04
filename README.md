# PyIsland

PyIsland是一个基于Python和PySide6开发的桌面小工具，提供系统状态监控和快捷操作功能。

## 功能特性

- **系统状态监控**：实时显示WiFi连接状态、蓝牙设备状态、电池状态
- **屏幕亮度控制**：通过界面调整屏幕亮度
- **健康提醒**：定时发送久坐提醒，关爱你的健康
- **系统快捷操作**：快速打开系统设置（网络、蓝牙、电池等）
- **美观界面**：透明置顶窗口，支持鼠标悬停展开/收起动画
- **系统托盘**：最小化到系统托盘，随时访问

## 技术栈

- **Python 3.13**
- **PySide6**：用于创建GUI界面
- **screen_brightness_control**：控制屏幕亮度
- **windows_bluetooth_watcher**：获取蓝牙设备信息
- **wmi**：获取电池信息
- **win11toast/win10toast**：发送系统通知

## 安装步骤

1. **克隆项目**
   ```bash
   git clone <项目地址>
   cd Python-island
   ```

2. **创建虚拟环境**
   ```bash
   python -m venv .venv
   ```

3. **激活虚拟环境**
   - Windows: `.venv\Scripts\activate`
   - Linux/macOS: `source .venv/bin/activate`

4. **安装依赖**
   ```bash
   pip install -r requirements.txt
   ```

5. **运行项目**
   ```bash
   python main.py
   ```

## 使用说明

1. **主界面**：桌面顶部会显示一个小窗口，显示当前时间和系统状态
2. **悬停展开**：鼠标悬停在窗口上时，会展开显示更多信息
3. **点击展开**：点击窗口会打开扩展窗口，可调整屏幕亮度
4. **系统托盘**：右键点击系统托盘图标，可启用/禁用鼠标穿透或退出程序
5. **快捷操作**：点击相应图标可快速打开系统设置

## 系统要求

- **操作系统**：Windows 10或Windows 11
- **Python版本**：3.13
- **分辨率**：推荐1920x1080及以上

## 注意事项

- 首次运行时，可能需要授予程序访问蓝牙和系统信息的权限
- 程序需要管理员权限才能调整屏幕亮度
- 如果遇到通知不显示的问题，请检查系统通知设置

## 项目结构

```
Python-island/
├── main.py          # 主程序入口
├── island.html      # 主界面HTML
├── island2.html     # 扩展窗口HTML
├── method/          # 功能模块
│   ├── brightness.py      # 亮度控制
│   ├── getbattery.py      # 电池信息
│   ├── getbluetooth.py    # 蓝牙设备信息
│   ├── getinternet.py     # 网络连接状态
│   ├── health.py          # 健康提醒
│   └── sendtoast.py       # 系统通知
├── assets/          # 资源文件
├── requirements.txt # 依赖项
└── .gitignore       # Git忽略文件
```

## 贡献

欢迎提交Issue和Pull Request来改进这个项目！
- 图标库：https://www.iconfont.cn/
- 官网：https://www.pyisland.com/
- 文档站：https://docs.pyisland.com/

## 许可证

[MIT License](LICENSE)
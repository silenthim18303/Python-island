# Pyisland - 现代灵动岛控制中心

Pyisland是一个基于PySide6开发的现代化灵动岛控制中心，提供直观的系统亮度、音量控制以及系统状态监控功能。

## 功能特点

- **灵动岛设计**：采用现代胶囊形状设计，初始状态显示时间，点击展开显示控制选项
- **亮度调节**：通过滑动条调节系统亮度，支持防抖机制，避免频繁调节
- **音量控制**：通过滑动条调节系统音量，同样支持防抖机制
- **系统状态监控**：显示当前WiFi连接、蓝牙设备和电池状态
- **鼠标拖动**：支持鼠标拖动调整灵动岛位置
- **自动收缩**：展开后失去焦点自动收缩
- **实时时间显示**：初始状态显示当前系统时间

## 项目结构

```
PyislandWeb/
├── app/
│   ├── __init__.py           # 包初始化
│   ├── island.py             # 主窗口，整合所有模块
│   ├── utils.py              # 工具函数（向后兼容）
│   ├── core/                 # 核心功能模块
│   │   ├── __init__.py
│   │   ├── worker.py         # 后台工作线程
│   │   └── config.py         # 配置常量
│   ├── ui/                   # UI组件模块
│   │   ├── __init__.py
│   │   ├── controls.py       # 控制面板组件
│   │   ├── status_bar.py     # 状态栏组件
│   │   └── url_dialog.py     # URL检测对话框
│   ├── services/             # 服务模块
│   │   ├── __init__.py
│   │   ├── clipboard.py      # 剪贴板服务
│   │   ├── system_status.py  # 系统状态服务
│   │   └── brightness.py     # 亮度控制服务
│   └── animations/           # 动画效果模块
│       ├── __init__.py
│       └── effects.py        # 展开/收起动画
├── resources/
│   ├── icons/                # 图标资源
│   │   ├── controls/         # 控制相关图标
│   │   │   ├── light.png     # 亮度图标
│   │   │   └── volume.png    # 音量图标
│   │   └── system/           # 系统状态图标
│   │       ├── battery.png    # 电池图标
│   │       ├── bluetooth.png  # 蓝牙图标
│   │       └── internet.png   # 网络图标
│   └── styles/
│       └── style.qss         # QSS样式文件
├── main.py                   # 应用入口
└── README.md                 # 项目说明文档
```

## 安装和运行

### 安装依赖

```bash
# 安装PySide6
pip install PySide6

# 安装其他依赖（如果需要）
pip install comtypes  # 用于音量控制的COM接口
```

### 运行应用

```bash
python main.py
```

## 配置和修改指南

### 1. 界面样式修改

修改 `resources/styles/style.qss` 文件可以调整界面样式：

- **灵动岛主体**：修改 `#IslandContainer` 样式
- **时间显示**：修改 `#TimeLabel` 样式
- **滑动条**：修改 `QSlider#CapsuleSlider` 相关样式
- **状态栏**：修改 `#StatusLabel` 样式

### 2. 功能调整

#### 调整防抖时间

在 `app/core/config.py` 文件中修改：

```python
DEBOUNCE_DELAY = 180  # 防抖时间，单位毫秒
```

#### 调整状态栏更新频率

在 `app/core/config.py` 文件中修改：

```python
STATUS_UPDATE_INTERVAL = 5000  # 更新频率，单位毫秒
```

#### 添加新功能

1. 在 `app/services/` 目录下创建新的服务类
2. 在 `app/ui/` 目录下创建新的UI组件
3. 在 `app/core/config.py` 中添加配置常量
4. 在 `app/island.py` 中整合新模块
5. 在 `resources/styles/style.qss` 中添加相应的样式

### 3. 图标替换

将自定义图标替换到 `resources/icons/` 目录下，确保文件名与代码中的引用一致：
- 亮度图标：`light.png`
- 音量图标：`volume.png`

## 技术栈

- **Python 3.7+**
- **PySide6**：Qt的Python绑定，用于GUI开发
- **QSS (Qt Style Sheets)**：用于界面样式定制
- **Windows API**：通过PowerShell和ctypes调用系统功能
- **COM接口**：用于音量控制

## 注意事项

1. **系统兼容性**：目前仅支持Windows系统，因为使用了Windows特定的API调用
2. **权限要求**：可能需要管理员权限才能修改系统亮度和音量
3. **图标路径**：确保 `resources/icons/` 目录存在且包含所需图标
4. **PowerShell**：需要系统安装PowerShell以获取系统状态信息

## 故障排除

### 常见错误

1. **`AttributeError: 'ModernIsland' object has no attribute 'wifi_label'`**
   - 原因：代码执行顺序问题
   - 解决方案：确保在调用 `update_status()` 之前创建所有标签

2. **`ImportError: cannot import name 'COMError' from 'ctypes'`**
   - 原因：Python 3.13中COMError不再从ctypes导入
   - 解决方案：从comtypes导入COMError

3. **`进程已结束，退出代码为 -1073741819 (0xC0000005)`**
   - 原因：Core Audio Controller的ctypes实现存在内存访问问题
   - 解决方案：使用PowerShell备选方案

4. **`动画卡顿，音量，显示器亮度调节卡顿`**
   - 原因：滑动条加了防抖机制，导致调节时卡顿，而PowerShell命令执行需要时间
   - 解决方案：不会了，发动群众力量解决一下

### 调试技巧

- 查看控制台输出获取详细错误信息
- 检查PowerShell命令是否能在系统中正常执行
- 确保图标文件路径正确

## 贡献指南

欢迎提交问题和改进建议！如果您想为项目贡献代码，请：

1. Fork项目仓库
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 打开Pull Request

## 许可证

本项目采用MIT许可证。

---

希望这个项目能为您提供一个现代化、直观的系统控制界面！如有任何问题，欢迎提出。
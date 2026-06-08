# MacIsland 配套 App

本目录包含 MacIsland 的配套 App 源代码，支持 iOS、Android 和鸿蒙平台。

## 目录结构

```
CompanionApps/
├── iOS/                    # iOS 配套 App
│   └── MacIslandCompanion/
├── Android/                # Android 配套 App
│   └── app/
└── HarmonyOS/              # 鸿蒙配套 App
    └── entry/
```

## 功能特性

- ✅ **自动发现**：自动发现同一网络下的 MacIsland 服务
- ✅ **多连接方式**：支持 WiFi、蓝牙、热点/WiFi Direct
- ✅ **通知转发**：将手机通知转发到 Mac
- ✅ **电池同步**：实时同步手机电池状态
- ✅ **心跳保活**：自动维持连接

## iOS App

### 开发环境

- Xcode 15.0+
- iOS 15.0+
- Swift 5.0+

### 构建步骤

1. 用 Xcode 打开 `iOS/MacIslandCompanion.xcodeproj`
2. 选择目标设备或模拟器
3. 点击运行按钮

### 主要文件

- `MacIslandCompanionApp.swift` - 应用入口
- `ConnectionManager.swift` - 连接管理器
- `ContentView.swift` - 主界面

## Android App

### 开发环境

- Android Studio Hedgehog+
- Android 10.0+ (API 29)
- Kotlin 1.9+

### 构建步骤

1. 用 Android Studio 打开 `Android/` 目录
2. 同步 Gradle
3. 连接设备或启动模拟器
4. 点击运行按钮

### 主要文件

- `MainActivity.kt` - 主 Activity
- `ConnectionManager.kt` - 连接管理器

### 权限要求

```xml
<uses-permission android:name="android.permission.NEARBY_WIFI_DEVICES" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

## 鸿蒙 App

### 开发环境

- DevEco Studio 4.0+
- HarmonyOS 4.0+
- ArkTS

### 构建步骤

1. 用 DevEco Studio 打开 `HarmonyOS/` 目录
2. 同步依赖
3. 连接设备或启动模拟器
4. 点击运行按钮

### 主要文件

- `pages/Index.ets` - 主页面
- `ConnectionManager.ets` - 连接管理器

## 连接协议

### 服务类型

```
_macisland._tcp
```

### 消息格式

```json
{
  "type": "deviceInfo",
  "payload": { ... },
  "timestamp": 1234567890,
  "messageID": "uuid"
}
```

### 消息类型

| 类型 | 说明 | 方向 |
|------|------|------|
| `deviceInfo` | 设备信息 | App → Mac |
| `batteryStatus` | 电池状态 | App → Mac |
| `notification` | 通知 | App → Mac |
| `ping` | 心跳请求 | Mac → App |
| `pong` | 心跳响应 | App → Mac |

## 开发指南

### 添加新功能

1. 在 `ConnectionManager` 中添加新消息类型
2. 在 UI 中添加相应按钮
3. 测试连接和消息发送

### 调试技巧

1. 查看控制台日志
2. 使用网络调试工具
3. 测试不同网络环境

## 常见问题

### Q: 无法发现 MacIsland 服务

A: 确保：
- 设备和 Mac 在同一 WiFi 网络
- MacIsland 应用已启动并开始配对
- 防火墙未阻止连接

### Q: 连接后立即断开

A: 检查：
- 网络稳定性
- 蓝牙是否开启（蓝牙连接时）
- 设备是否支持所选连接方式

### Q: 通知未转发

A: 确保：
- 应用已授权通知权限
- 应用在后台运行
- 系统未限制后台活动

## 许可证

MIT License

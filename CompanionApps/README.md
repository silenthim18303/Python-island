# MacIsland 配套 App

本目录包含 MacIsland 的配套 App 源代码，支持 iOS、Android 和鸿蒙平台。

## 目录结构

```
CompanionApps/
├── iOS/                         # iOS 配套 App
│   ├── MacIslandCompanion.xcodeproj/
│   └── MacIslandCompanion/
├── Android/                     # Android 配套 App
│   └── app/
├── HarmonyOS/                   # 鸿蒙配套 App
│   └── entry/
├── build.sh                     # 构建脚本
└── README.md                    # 本文件
```

## 快速开始

### 使用构建脚本

```bash
# 构建 iOS App
./build.sh ios

# 构建 Android App
./build.sh android

# 构建鸿蒙 App
./build.sh harmonyos

# 构建所有 App
./build.sh all
```

构建产物将保存在 `build/` 目录中。

## iOS App

### 开发环境

- macOS 13.0+
- Xcode 15.0+
- iOS 15.0+

### 手动构建

1. 用 Xcode 打开 `iOS/MacIslandCompanion.xcodeproj`
2. 选择目标设备或模拟器
3. 点击运行按钮 (⌘R)

### 创建 IPA

1. 在 Xcode 中选择 Product → Archive
2. 在 Organizer 中选择 Distribute App
3. 选择 Development 或 Ad Hoc 分发
4. 导出 IPA 文件

### 主要文件

| 文件 | 说明 |
|------|------|
| `MacIslandCompanionApp.swift` | 应用入口 |
| `ConnectionManager.swift` | 连接管理器 |
| `ContentView.swift` | 主界面 |

## Android App

### 开发环境

- Android Studio Hedgehog (2023.1.1)+
- JDK 17+
- Android SDK 34+

### 手动构建

1. 用 Android Studio 打开 `Android/` 目录
2. 等待 Gradle 同步完成
3. 选择设备或模拟器
4. 点击运行按钮 (⌃R)

### 创建 APK

1. 选择 Build → Build Bundle(s) / APK(s) → Build APK(s)
2. 或使用命令行：
   ```bash
   cd Android
   ./gradlew assembleDebug
   ```
3. APK 位于 `app/build/outputs/apk/debug/`

### 主要文件

| 文件 | 说明 |
|------|------|
| `MainActivity.kt` | 主 Activity |
| `ConnectionManager.kt` | 连接管理器 |
| `build.gradle.kts` | 构建配置 |
| `AndroidManifest.xml` | 应用清单 |

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
- HarmonyOS SDK 4.0+
- Node.js 16+

### 手动构建

1. 用 DevEco Studio 打开 `HarmonyOS/` 目录
2. 等待依赖同步完成
3. 选择设备或模拟器
4. 点击运行按钮

### 创建 HAP

1. 选择 Build → Build Hap(s)/APP(s)
2. 或使用命令行：
   ```bash
   cd HarmonyOS
   hvigorw assembleHap
   ```
3. HAP 位于 `entry/build/outputs/`

### 主要文件

| 文件 | 说明 |
|------|------|
| `pages/Index.ets` | 主页面 |
| `ConnectionManager.ets` | 连接管理器 |
| `build-profile.json5` | 构建配置 |

## 功能特性

### 连接功能

- ✅ **自动发现**：自动发现同一网络下的 MacIsland 服务
- ✅ **多连接方式**：WiFi、蓝牙、热点/WiFi Direct
- ✅ **心跳保活**：自动维持连接
- ✅ **自动重连**：连接断开后自动重连

### 数据同步

- ✅ **通知转发**：将手机通知转发到 Mac
- ✅ **电池同步**：实时同步手机电池状态
- ✅ **设备信息**：同步设备名称、型号、系统版本

### 用户界面

- ✅ **Material Design 3**：Android 使用最新设计语言
- ✅ **SwiftUI**：iOS 使用原生 SwiftUI
- ✅ **ArkUI**：鸿蒙使用原生 ArkUI

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

### 设备信息格式

```json
{
  "name": "iPhone 16 Pro",
  "model": "iPhone17,1",
  "systemVersion": "18.0",
  "deviceType": "iphone"
}
```

### 电池状态格式

```json
{
  "level": 0.85,
  "isCharging": false,
  "isLowPowerMode": false
}
```

### 通知格式

```json
{
  "id": "uuid",
  "title": "通知标题",
  "body": "通知内容",
  "appName": "App名称",
  "timestamp": "2026-06-08T12:00:00Z"
}
```

## 安装指南

### iOS

1. 使用 Xcode 构建 IPA
2. 通过 TestFlight 或企业证书分发
3. 或直接连接设备安装

### Android

1. 构建 APK 文件
2. 传输到手机
3. 允许安装未知来源应用
4. 安装 APK

### 鸿蒙

1. 构建 HAP 文件
2. 通过 DevEco Studio 安装
3. 或通过华为应用市场分发

## 故障排除

### 无法发现 MacIsland 服务

- 确保设备和 Mac 在同一 WiFi 网络
- 检查防火墙设置
- 重启 MacIsland 应用

### 连接失败

- 检查网络连接
- 确认端口未被占用
- 查看控制台日志

### 通知未转发

- 确保设备已授权通知权限
- 检查应用后台运行权限
- 查看通知设置

## 开发指南

### 添加新功能

1. 在 `ConnectionManager` 中添加新消息类型
2. 在 UI 中添加相应按钮
3. 测试连接和消息发送

### 调试技巧

1. 查看控制台日志
2. 使用网络调试工具
3. 测试不同网络环境

## 许可证

MIT License

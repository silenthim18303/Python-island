# MacIsland 设备配对指南

## 概述

MacIsland 支持通过多种方式连接手机和其他设备：
- **WiFi**：同一网络自动发现
- **蓝牙**：近距离自动连接
- **热点/WiFi Direct**：临时连接

## 连接步骤

### 1. Mac 端设置

1. 打开 MacIsland 应用
2. 点击菜单栏图标 → 设置
3. 选择「设备配对」分类
4. 点击「开始配对」按钮
5. 应用会开始广播，等待设备连接

### 2. iPhone/iPad 连接

#### 方法一：使用快捷指令（推荐）

1. 在 iPhone 上打开「快捷指令」App
2. 创建新快捷指令
3. 添加以下操作：
   - 「获取网络」→ 获取当前 WiFi 名称
   - 「如果」→ WiFi 名称包含你的网络名
   - 「URL」→ 输入 Mac 的 IP 地址
   - 「获取 URL 内容」→ 发送连接请求

#### 方法二：使用 Python 脚本（开发者）

1. 在 iPhone 上安装 Pythonista 或 Pyto
2. 运行测试客户端脚本（见下文）

#### 方法三：使用配套 App（即将发布）

我们将发布 iOS 配套 App，支持：
- 自动发现 MacIsland 服务
- 一键连接
- 通知转发
- 电池状态同步

### 3. Android 连接

#### 方法一：使用 Termux

1. 在 Android 上安装 Termux
2. 安装 Python：`pkg install python`
3. 运行测试客户端脚本

#### 方法二：使用配套 App（即将发布）

我们将发布 Android 配套 App，支持：
- 自动发现
- 一键连接
- 通知转发

### 4. 鸿蒙设备连接

#### 方法一：使用 DevEco Studio

1. 使用 DevEco Studio 创建应用
2. 实现 MultipeerConnectivity 或 Network 框架
3. 连接到 MacIsland 服务

#### 方法二：使用配套 App（即将发布）

我们将发布鸿蒙配套 App。

## 测试连接

### 使用 Python 测试客户端

1. 确保 Mac 和手机在同一 WiFi 网络
2. 在 Mac 上启动 MacIsland 并开始配对
3. 在手机上运行测试脚本：

```bash
# 安装依赖
pip3 install zeroconf

# 运行测试客户端
python3 test_client.py
```

### 手动连接

如果自动发现失败，可以手动连接：

1. 获取 Mac 的 IP 地址
2. 在测试客户端中输入 IP 地址和端口
3. 点击连接

## 连接方式详解

### WiFi 连接

- **原理**：使用 Bonjour (mDNS) 服务发现
- **要求**：设备和 Mac 在同一 WiFi 网络
- **优点**：自动发现，无需手动配置
- **协议**：TCP + JSON 消息

### 蓝牙连接

- **原理**：使用 MultipeerConnectivity 框架
- **要求**：设备支持蓝牙 4.0+
- **优点**：无需网络，近距离连接
- **协议**：MultipeerConnectivity + JSON 消息

### 热点/WiFi Direct 连接

- **原理**：使用 WiFi Direct 协议
- **要求**：设备支持 WiFi Direct
- **优点**：无需路由器，点对点连接
- **协议**：MultipeerConnectivity + JSON 消息

## 消息协议

### 消息格式

```json
{
  "type": "deviceInfo",
  "payload": "<base64 encoded JSON>",
  "timestamp": "2026-06-08T12:00:00Z",
  "messageID": "uuid"
}
```

### 消息类型

| 类型 | 说明 | 方向 |
|------|------|------|
| `deviceInfo` | 设备信息 | 设备 → Mac |
| `batteryStatus` | 电池状态 | 设备 → Mac |
| `notification` | 通知 | 设备 → Mac |
| `ping` | 心跳请求 | Mac → 设备 |
| `pong` | 心跳响应 | 设备 → Mac |

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

## 故障排除

### 1. 无法发现设备

- 确保设备和 Mac 在同一 WiFi 网络
- 检查防火墙设置
- 重启 MacIsland 应用

### 2. 连接失败

- 检查网络连接
- 确认端口未被占用
- 查看控制台日志

### 3. 连接后断开

- 检查网络稳定性
- 确保蓝牙已开启（蓝牙连接时）
- 查看电池优化设置

### 4. 通知未转发

- 确保设备已授权通知权限
- 检查应用后台运行权限
- 查看通知设置

## 开发者指南

### iOS 开发

使用 Network 框架或 MultipeerConnectivity：

```swift
// Network 框架 (WiFi)
let connection = NWConnection(host: "192.168.1.100", port: 0, using: .tcp)

// MultipeerConnectivity (蓝牙/WiFi Direct)
let session = MCSession(peer: peerID)
let advertiser = MCNearbyServiceAdvertiser(peer: peerID, serviceType: "macisland-svc")
```

### Android 开发

使用 NSD (Network Service Discovery) 或 Bluetooth：

```java
// NSD (WiFi)
NsdManager nsdManager = (NsdManager) getSystemService(NSD_SERVICE);
nsdManager.discoverServices("_macisland._tcp", NsdManager.PROTOCOL_DNS_SD, listener);

// Bluetooth
BluetoothAdapter adapter = BluetoothAdapter.getDefaultAdapter();
```

### 鸿蒙开发

使用分布式软总线或蓝牙：

```typescript
// 分布式软总线
import distributedDeviceManager from '@ohos.distributedDeviceManager';

// 蓝牙
import bluetooth from '@ohos.bluetooth';
```

## 联系我们

如有问题或建议，请提交 Issue：
https://github.com/MacIsland/MacIsland/issues

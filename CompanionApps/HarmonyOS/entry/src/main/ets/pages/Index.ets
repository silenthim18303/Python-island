import { ConnectionManager } from '../ConnectionManager'
import { promptAction } from '@kit.ArkUI'

@Entry
@Component
struct Index {
  @State connectionManager: ConnectionManager = new ConnectionManager()
  @State isConnected: boolean = false
  @State isSearching: boolean = false
  @State connectionStatus: string = '未连接'
  @State macName: string = ''
  @State errorMessage: string = ''

  build() {
    Column() {
      // 标题
      Text('MacIsland')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 20 })

      // 连接状态卡片
      this.ConnectionStatusCard()

      // 连接按钮
      Button(this.isConnected ? '断开连接' : '搜索 MacIsland')
        .width('100%')
        .height(50)
        .margin({ top: 20 })
        .backgroundColor(this.isConnected ? '#F44336' : '#2196F3')
        .onClick(() => {
          if (this.isConnected) {
            this.connectionManager.disconnect()
          } else {
            this.connectionManager.startSearching()
          }
        })
        .enabled(!this.isSearching)

      // 测试功能
      if (this.isConnected) {
        this.TestSection()
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(16)
  }

  @Builder
  ConnectionStatusCard() {
    Column() {
      // 状态图标
      Text(this.isConnected ? '✓' : '📡')
        .fontSize(48)
        .fontColor(this.isConnected ? '#4CAF50' : '#2196F3')

      // 状态文本
      Text(this.connectionStatus)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 12 })

      // Mac 名称
      if (this.isConnected && this.macName.length > 0) {
        Text('已连接到 ' + this.macName)
          .fontSize(14)
          .fontColor('#666666')
          .margin({ top: 8 })
      }

      // 错误信息
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor('#F44336')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .padding(24)
    .backgroundColor('#FFFFFF')
    .borderRadius(16)
    .shadow({
      radius: 10,
      color: '#1A000000',
      offsetX: 0,
      offsetY: 5
    })
  }

  @Builder
  TestSection() {
    Column() {
      Text('测试功能')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 20, bottom: 12 })

      // 发送测试通知
      Button('发送测试通知')
        .width('100%')
        .height(45)
        .backgroundColor('#FF9800')
        .onClick(() => {
          this.connectionManager.sendNotification(
            '测试通知',
            '这是一条来自鸿蒙设备的测试通知',
            'MacIsland Companion'
          )
          promptAction.showToast({ message: '测试通知已发送' })
        })

      // 连接信息
      Column() {
        Text('连接信息')
          .fontSize(14)
          .fontColor('#666666')
          .margin({ bottom: 8 })

        this.InfoRow('设备名称', this.getDeviceName())
        this.InfoRow('系统版本', 'HarmonyOS ' + this.getSystemVersion())
        this.InfoRow('连接状态', this.isConnected ? '已连接' : '未连接')
      }
      .width('100%')
      .padding(16)
        .backgroundColor('#F5F5F5')
        .borderRadius(12)
        .margin({ top: 12 })
    }
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
      Blank()
      Text(value)
        .fontSize(14)
        .fontColor('#666666')
    }
    .width('100%')
    .margin({ bottom: 4 })
  }

  getDeviceName(): string {
    // 获取设备名称
    return 'HarmonyOS Device'
  }

  getSystemVersion(): string {
    // 获取系统版本
    return '4.0'
  }
}

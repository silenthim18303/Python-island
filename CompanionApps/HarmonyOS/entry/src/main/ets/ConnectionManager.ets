import { socket } from '@kit.NetworkKit'
import { deviceInfo } from '@kit.BasicServicesKit'
import { batteryInfo } from '@kit.BasicServicesKit'

const SERVICE_TYPE = '_macisland._tcp'

export class ConnectionManager {
  isConnected: boolean = false
  isSearching: boolean = false
  connectionStatus: string = '未连接'
  macName: string = ''
  errorMessage: string = ''

  private tcpSocket: socket.TCPSocket | null = null
  private pingInterval: number = -1
  private batteryInterval: number = -1

  constructor() {
    this.tcpSocket = socket.constructTCPSocketInstance()
  }

  async startSearching() {
    if (this.isSearching) return

    this.isSearching = true
    this.connectionStatus = '搜索中...'
    this.errorMessage = ''

    try {
      // 使用 NSD 发现服务
      // 注意：鸿蒙的 NSD API 可能需要不同的实现
      // 这里使用简化的实现
      this.connectionStatus = '等待连接...'
    } catch (error) {
      this.isSearching = false
      this.connectionStatus = '搜索失败'
      this.errorMessage = String(error)
    }
  }

  stopSearching() {
    this.isSearching = false
  }

  disconnect() {
    if (this.tcpSocket) {
      this.tcpSocket.close()
      this.tcpSocket = null
    }

    this.isConnected = false
    this.connectionStatus = '已断开'
    this.macName = ''
    this.stopTimers()
  }

  async connect(host: string, port: number) {
    try {
      this.connectionStatus = '连接中...'

      this.tcpSocket = socket.constructTCPSocketInstance()

      // 连接
      await this.tcpSocket.connect({
        address: {
          address: host,
          family: 1
        },
        port: port,
        timeout: 10000
      })

      this.isConnected = true
      this.isSearching = false
      this.connectionStatus = '已连接'
      this.macName = host

      // 发送设备信息
      this.sendDeviceInfo()

      // 发送电池状态
      this.sendBatteryStatus()

      // 启动定时器
      this.startTimers()

      // 接收消息
      this.receiveMessages()

    } catch (error) {
      this.connectionStatus = '连接失败'
      this.errorMessage = String(error)
    }
  }

  sendNotification(title: string, body: string, appName: string) {
    if (!this.isConnected) return

    const notification = {
      id: this.generateUUID(),
      title: title,
      body: body,
      appName: appName,
      timestamp: Date.now()
    }

    this.sendMessage('notification', notification)
  }

  private sendDeviceInfo() {
    const deviceInfoObj = {
      name: deviceInfo.productModel,
      model: deviceInfo.productModel,
      systemVersion: deviceInfo.osReleaseType,
      deviceType: 'harmonyos'
    }

    this.sendMessage('deviceInfo', deviceInfoObj)
  }

  private sendBatteryStatus() {
    const batteryStatus = {
      level: batteryInfo.batterySOC / 100,
      isCharging: batteryInfo.chargingStatus === batteryInfo.ChargingStatus.CHARGING,
      isLowPowerMode: false
    }

    this.sendMessage('batteryStatus', batteryStatus)
  }

  private sendMessage(type: string, payload: object) {
    if (!this.tcpSocket || !this.isConnected) return

    const message = {
      type: type,
      payload: payload,
      timestamp: Date.now(),
      messageID: this.generateUUID()
    }

    const data = JSON.stringify(message)
    const buffer = this.stringToArrayBuffer(data)

    // 添加长度头
    const lengthBuffer = new ArrayBuffer(4)
    const lengthView = new DataView(lengthBuffer)
    lengthView.setUint32(0, buffer.byteLength, false) // 大端序

    // 合并长度头和消息体
    const combinedBuffer = this.combineBuffers(lengthBuffer, buffer)

    this.tcpSocket.send({ data: combinedBuffer }).catch((error: Error) => {
      console.error('Send failed:', error)
    })
  }

  private receiveMessages() {
    if (!this.tcpSocket) return

    this.tcpSocket.on('message', (value: socket.TCPRecvMessage) => {
      try {
        const data = value.message as ArrayBuffer
        const message = JSON.parse(this.arrayBufferToString(data))
        this.handleMessage(message)
      } catch (error) {
        console.error('Parse message failed:', error)
      }
    })
  }

  private handleMessage(message: object) {
    const type = (message as any).type

    switch (type) {
      case 'ping':
        this.sendMessage('ping', {})
        break
      case 'pong':
        // 心跳响应
        break
      default:
        console.log('Received message:', type)
    }
  }

  private startTimers() {
    // 每 30 秒发送电池状态
    this.batteryInterval = setInterval(() => {
      this.sendBatteryStatus()
    }, 30000)

    // 每 15 秒发送心跳
    this.pingInterval = setInterval(() => {
      this.sendMessage('ping', {})
    }, 15000)
  }

  private stopTimers() {
    if (this.batteryInterval !== -1) {
      clearInterval(this.batteryInterval)
      this.batteryInterval = -1
    }
    if (this.pingInterval !== -1) {
      clearInterval(this.pingInterval)
      this.pingInterval = -1
    }
  }

  private generateUUID(): string {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
      const r = Math.random() * 16 | 0
      const v = c === 'x' ? r : (r & 0x3 | 0x8)
      return v.toString(16)
    })
  }

  private stringToArrayBuffer(str: string): ArrayBuffer {
    const encoder = new TextEncoder()
    return encoder.encode(str).buffer
  }

  private arrayBufferToString(buffer: ArrayBuffer): string {
    const decoder = new TextDecoder()
    return decoder.decode(buffer)
  }

  private combineBuffers(buffer1: ArrayBuffer, buffer2: ArrayBuffer): ArrayBuffer {
    const combined = new ArrayBuffer(buffer1.byteLength + buffer2.byteLength)
    const view = new Uint8Array(combined)
    view.set(new Uint8Array(buffer1), 0)
    view.set(new Uint8Array(buffer2), buffer1.byteLength)
    return combined
  }
}

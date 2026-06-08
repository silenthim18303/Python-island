package com.macisland.companion

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import android.os.BatteryManager
import android.util.Log
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import org.json.JSONObject
import java.io.InputStream
import java.io.OutputStream
import java.net.Socket
import java.util.UUID

class ConnectionManager(private val context: Context) {

    companion object {
        private const val TAG = "ConnectionManager"
        private const val SERVICE_TYPE = "_macisland._tcp"
    }

    // 状态
    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected

    private val _isSearching = MutableStateFlow(false)
    val isSearching: StateFlow<Boolean> = _isSearching

    private val _connectionStatus = MutableStateFlow("未连接")
    val connectionStatus: StateFlow<String> = _connectionStatus

    private val _macName = MutableStateFlow("")
    val macName: StateFlow<String> = _macName

    private val _errorMessage = MutableStateFlow<String?>(null)
    val errorMessage: StateFlow<String?> = _errorMessage

    // NSD
    private var nsdManager: NsdManager? = null
    private var discoveryListener: NsdManager.DiscoveryListener? = null

    // 连接
    private var socket: Socket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null

    // 定时器
    private var pingThread: Thread? = null
    private var batteryThread: Thread? = null

    init {
        nsdManager = context.getSystemService(Context.NSD_SERVICE) as NsdManager
    }

    fun startSearching() {
        if (_isSearching.value) return

        _isSearching.value = true
        _connectionStatus.value = "搜索中..."
        _errorMessage.value = null

        discoveryListener = createDiscoveryListener()
        nsdManager?.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
    }

    fun stopSearching() {
        _isSearching.value = false
        discoveryListener?.let { nsdManager?.stopServiceDiscovery(it) }
    }

    fun disconnect() {
        socket?.close()
        socket = null
        inputStream = null
        outputStream = null

        _isConnected.value = false
        _connectionStatus.value = "已断开"
        _macName.value = ""

        stopTimers()
    }

    fun sendNotification(title: String, body: String, appName: String) {
        if (!_isConnected.value) return

        val notification = JSONObject().apply {
            put("id", UUID.randomUUID().toString())
            put("title", title)
            put("body", body)
            put("appName", appName)
            put("timestamp", System.currentTimeMillis())
        }

        sendMessage("notification", notification)
    }

    private fun createDiscoveryListener(): NsdManager.DiscoveryListener {
        return object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {
                Log.d(TAG, "Discovery started")
            }

            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service found: ${serviceInfo.serviceName}")
                nsdManager?.resolveService(serviceInfo, createResolveListener())
            }

            override fun onServiceLost(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service lost: ${serviceInfo.serviceName}")
                if (_macName.value == serviceInfo.serviceName) {
                    _isConnected.value = false
                    _connectionStatus.value = "连接断开"
                    _macName.value = ""
                    stopTimers()
                }
            }

            override fun onDiscoveryStopped(serviceType: String) {
                Log.d(TAG, "Discovery stopped")
            }

            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Start discovery failed: $errorCode")
                _isSearching.value = false
                _connectionStatus.value = "搜索失败"
                _errorMessage.value = "错误代码: $errorCode"
            }

            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {
                Log.e(TAG, "Stop discovery failed: $errorCode")
            }
        }
    }

    private fun createResolveListener(): NsdManager.ResolveListener {
        return object : NsdManager.ResolveListener {
            override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                Log.e(TAG, "Resolve failed: $errorCode")
            }

            override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                Log.d(TAG, "Service resolved: ${serviceInfo.host}")
                connectToService(serviceInfo)
            }
        }
    }

    private fun connectToService(serviceInfo: NsdServiceInfo) {
        Thread {
            try {
                _connectionStatus.value = "连接中..."

                val socket = Socket(serviceInfo.host, serviceInfo.port)
                this.socket = socket
                inputStream = socket.getInputStream()
                outputStream = socket.getOutputStream()

                _isConnected.value = true
                _isSearching.value = false
                _connectionStatus.value = "已连接"
                _macName.value = serviceInfo.serviceName

                // 发送设备信息
                sendDeviceInfo()

                // 发送电池状态
                sendBatteryStatus()

                // 启动定时器
                startTimers()

                // 接收消息
                receiveMessages()

            } catch (e: Exception) {
                Log.e(TAG, "Connection failed", e)
                _connectionStatus.value = "连接失败"
                _errorMessage.value = e.message
            }
        }.start()
    }

    private fun sendDeviceInfo() {
        val deviceInfo = JSONObject().apply {
            put("name", Build.MODEL)
            put("model", Build.DEVICE)
            put("systemVersion", Build.VERSION.RELEASE)
            put("deviceType", "android")
        }

        sendMessage("deviceInfo", deviceInfo)
    }

    private fun sendBatteryStatus() {
        val batteryManager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val batteryLevel = batteryManager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY) / 100.0
        val isCharging = batteryManager.isCharging

        val batteryStatus = JSONObject().apply {
            put("level", batteryLevel)
            put("isCharging", isCharging)
            put("isLowPowerMode", false)
        }

        sendMessage("batteryStatus", batteryStatus)
    }

    private fun sendMessage(type: String, payload: JSONObject) {
        val message = JSONObject().apply {
            put("type", type)
            put("payload", payload)
            put("timestamp", System.currentTimeMillis())
            put("messageID", UUID.randomUUID().toString())
        }

        Thread {
            try {
                val data = message.toString().toByteArray()
                val length = data.size.toByteArray()
                outputStream?.write(length)
                outputStream?.write(data)
                outputStream?.flush()
            } catch (e: Exception) {
                Log.e(TAG, "Send failed", e)
            }
        }.start()
    }

    private fun receiveMessages() {
        val buffer = ByteArray(4096)

        while (_isConnected.value) {
            try {
                // 读取长度头
                val lengthBytes = ByteArray(4)
                inputStream?.read(lengthBytes)
                val length = lengthBytes.toInt()

                if (length > 0 && length < 1048576) {
                    // 读取消息体
                    val data = ByteArray(length)
                    var bytesRead = 0
                    while (bytesRead < length) {
                        val read = inputStream?.read(data, bytesRead, length - bytesRead) ?: -1
                        if (read == -1) break
                        bytesRead += read
                    }

                    // 处理消息
                    val message = String(data)
                    handleMessage(message)
                }
            } catch (e: Exception) {
                if (_isConnected.value) {
                    Log.e(TAG, "Receive failed", e)
                    _isConnected.value = false
                    _connectionStatus.value = "连接断开"
                    _macName.value = ""
                    stopTimers()
                }
                break
            }
        }
    }

    private fun handleMessage(message: String) {
        try {
            val json = JSONObject(message)
            val type = json.getString("type")

            when (type) {
                "ping" -> {
                    sendMessage("ping", JSONObject())
                }
                "pong" -> {
                    // 心跳响应
                }
                else -> {
                    Log.d(TAG, "Received message: $type")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Handle message failed", e)
        }
    }

    private fun startTimers() {
        // 每 30 秒发送电池状态
        batteryThread = Thread {
            while (_isConnected.value) {
                Thread.sleep(30000)
                sendBatteryStatus()
            }
        }
        batteryThread?.start()

        // 每 15 秒发送心跳
        pingThread = Thread {
            while (_isConnected.value) {
                Thread.sleep(15000)
                sendMessage("ping", JSONObject())
            }
        }
        pingThread?.start()
    }

    private fun stopTimers() {
        batteryThread?.interrupt()
        batteryThread = null
        pingThread?.interrupt()
        pingThread = null
    }

    private fun ByteArray.toInt(): Int {
        return (this[0].toInt() and 0xFF shl 24) or
               (this[1].toInt() and 0xFF shl 16) or
               (this[2].toInt() and 0xFF shl 8) or
               (this[3].toInt() and 0xFF)
    }

    private fun Int.toByteArray(): ByteArray {
        return byteArrayOf(
            (this shr 24).toByte(),
            (this shr 16).toByte(),
            (this shr 8).toByte(),
            this.toByte()
        )
    }
}

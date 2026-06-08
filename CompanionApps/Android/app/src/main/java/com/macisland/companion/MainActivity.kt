package com.macisland.companion

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat

class MainActivity : ComponentActivity() {

    private lateinit var connectionManager: ConnectionManager

    private val requestPermissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { permissions ->
        // 权限已授予
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        connectionManager = ConnectionManager(this)
        requestPermissions()

        setContent {
            MaterialTheme {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    MainScreen(connectionManager)
                }
            }
        }
    }

    private fun requestPermissions() {
        val permissions = mutableListOf<String>()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.NEARBY_WIFI_DEVICES)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            }
            if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
                permissions.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }

        if (ContextCompat.checkSelfPermission(this, Manifest.permission.BLUETOOTH_CONNECT)
            != PackageManager.PERMISSION_GRANTED) {
            permissions.add(Manifest.permission.BLUETOOTH_CONNECT)
        }

        if (permissions.isNotEmpty()) {
            requestPermissionLauncher.launch(permissions.toTypedArray())
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MainScreen(connectionManager: ConnectionManager) {
    val isConnected by connectionManager.isConnected.collectAsState()
    val isSearching by connectionManager.isSearching.collectAsState()
    val connectionStatus by connectionManager.connectionStatus.collectAsState()
    val macName by connectionManager.macName.collectAsState()
    val errorMessage by connectionManager.errorMessage.collectAsState()

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("MacIsland") },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primaryContainer
                )
            )
        }
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // 连接状态卡片
            ConnectionStatusCard(
                isConnected = isConnected,
                connectionStatus = connectionStatus,
                macName = macName,
                errorMessage = errorMessage
            )

            // 连接按钮
            Button(
                onClick = {
                    if (isConnected) {
                        connectionManager.disconnect()
                    } else {
                        connectionManager.startSearching()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                enabled = !isSearching,
                colors = ButtonDefaults.buttonColors(
                    containerColor = if (isConnected) Color.Red else MaterialTheme.colorScheme.primary
                )
            ) {
                Icon(
                    imageVector = if (isConnected) Icons.Default.Close else Icons.Default.Search,
                    contentDescription = null
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(if (isConnected) "断开连接" else "搜索 MacIsland")
            }

            // 测试功能
            if (isConnected) {
                TestSection(connectionManager)
            }

            Spacer()
        }
    }
}

@Composable
fun ConnectionStatusCard(
    isConnected: Boolean,
    connectionStatus: String,
    macName: String,
    errorMessage: String?
) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            // 状态图标
            Icon(
                imageVector = if (isConnected) Icons.Default.CheckCircle else Icons.Default.Antenna,
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = if (isConnected) Color.Green else MaterialTheme.colorScheme.primary
            )

            // 状态文本
            Text(
                text = connectionStatus,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )

            // Mac 名称
            if (isConnected && macName.isNotEmpty()) {
                Text(
                    text = "已连接到 $macName",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            // 错误信息
            if (errorMessage != null) {
                Text(
                    text = errorMessage,
                    fontSize = 12.sp,
                    color = Color.Red
                )
            }
        }
    }
}

@Composable
fun TestSection(connectionManager: ConnectionManager) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
            text = "测试功能",
            fontSize = 16.sp,
            fontWeight = FontWeight.Bold
        )

        // 发送测试通知
        Button(
            onClick = {
                connectionManager.sendNotification(
                    title = "测试通知",
                    body = "这是一条来自 Android 的测试通知",
                    appName = "MacIsland Companion"
                )
            },
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFFF9800))
        ) {
            Icon(Icons.Default.Notifications, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("发送测试通知")
        }

        // 连接信息
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(12.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Text(
                    text = "连接信息",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )

                InfoRow("设备名称", Build.MODEL)
                InfoRow("系统版本", "Android ${Build.VERSION.RELEASE}")
                InfoRow("连接状态", if (connectionManager.isConnected.collectAsState().value) "已连接" else "未连接")
            }
        }
    }
}

@Composable
fun InfoRow(label: String, value: String) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, fontSize = 14.sp)
        Text(text = value, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

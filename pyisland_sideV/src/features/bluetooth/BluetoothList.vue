<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
// 引入蓝牙图标
import bluetoothIcon from '../../assets/bluetooth.png'

// 已连接的蓝牙设备列表
const connectedDevices = ref([])
const statusMessage = ref('正在扫描蓝牙设备...')

// 计算圆环的stroke-dashoffset
function getCircleOffset(value, circumference = 2 * Math.PI * 14) {
  return circumference - (value / 100) * circumference
}

// 根据电量获取圆环颜色
function getBatteryColor(value) {
  if (value > 60) return '#4ade80' // 绿色
  if (value > 20) return '#facc15' // 黄色
  return '#f87171' // 红色
}

// 处理后端推送的蓝牙设备更新
function handleBluetoothDevicesUpdate(devices) {
  console.log('[Bluetooth] 收到后端推送的设备列表:', devices)
  connectedDevices.value = devices
  statusMessage.value = `已连接 ${devices.length} 个蓝牙设备`
}

// 挂载时注册全局函数
onMounted(() => {
  window.handleBluetoothDevicesUpdate = handleBluetoothDevicesUpdate
})

// 卸载时清理全局函数
onBeforeUnmount(() => {
  if (window.handleBluetoothDevicesUpdate === handleBluetoothDevicesUpdate) {
    delete window.handleBluetoothDevicesUpdate
  }
})
</script>

<template>
  <div class="bluetooth-container">
    <div class="bluetooth-header">
      <div>
        <h2 class="bluetooth-title">蓝牙设备</h2>
        <div class="bluetooth-subtitle">{{ statusMessage }}</div>
      </div>
      <span class="status-chip">正在扫描</span>
    </div>

    <div class="device-list">
      <div 
        v-for="device in connectedDevices" 
        :key="device.id"
        class="device-item"
      >
        <div class="device-left">
          <!-- 蓝牙图标 -->
          <img :src="bluetoothIcon" alt="蓝牙" class="bluetooth-icon" />
          <div class="device-info">
            <div class="device-name">{{ device.name }}</div>
          </div>
        </div>
        <!-- 电量圆环 - 使用SVG实现，基于icon-park的圆环设计理念 -->
        <div class="battery-circle">
          <svg width="36" height="36" viewBox="0 0 36 36">
            <!-- 背景圆环 -->
            <circle
              cx="18"
              cy="18"
              r="14"
              fill="none"
              stroke="rgba(255,255,255,0.2)"
              stroke-width="3"
            />
            <!-- 进度圆环 -->
            <circle
              cx="18"
              cy="18"
              r="14"
              fill="none"
              :stroke="device.batteryValue > 60 ? '#4ade80' : device.batteryValue > 20 ? '#facc15' : '#f87171'"
              stroke-width="3"
              stroke-linecap="round"
              stroke-dasharray="87.96"
              :stroke-dashoffset="87.96 - (device.batteryValue / 100) * 87.96"
              transform="rotate(-90 18 18)"
              class="progress-ring"
            />
            <!-- 电量文字 -->
            <text
              x="18"
              y="21"
              text-anchor="middle"
              fill="white"
              font-size="10"
              font-weight="600"
            >{{ device.battery }}</text>
          </svg>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.bluetooth-container {
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 18px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
}

.bluetooth-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  gap: 12px;
}

.bluetooth-title {
  color: white;
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0 0 4px;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.bluetooth-subtitle {
  color: rgba(255, 255, 255, 0.65);
  font-size: 0.82rem;
  text-align: left;
}

.status-chip {
  padding: 4px 12px;
  border-radius: 12px;
  background: rgba(34, 197, 94, 0.3);
  color: #4ade80;
  font-size: 0.75rem;
  white-space: nowrap;
  border: 1px solid rgba(34, 197, 94, 0.4);
}

.device-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.device-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px;
  border-radius: 12px;
  background: rgba(34, 197, 94, 0.15);
  border: 1px solid rgba(34, 197, 94, 0.4);
}

.device-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.bluetooth-icon {
  width: 28px;
  height: 28px;
  object-fit: contain;
}

.device-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.device-name {
  color: white;
  font-size: 0.95rem;
  font-weight: 500;
}

.battery-circle {
  display: flex;
  align-items: center;
  justify-content: center;
}

.progress-ring {
  transition: stroke-dashoffset 0.5s ease;
}

@media (max-width: 768px) {
  .bluetooth-container {
    padding: 14px;
  }
}
</style>

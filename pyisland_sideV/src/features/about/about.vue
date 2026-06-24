<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const now = ref(new Date())
let clockTimerId = null

const timeText = computed(function () {
  const date = now.value
  const hour = String(date.getHours()).padStart(2, '0')
  const minute = String(date.getMinutes()).padStart(2, '0')
  const second = String(date.getSeconds()).padStart(2, '0')
  return `${hour}:${minute}:${second}`
})

const dateText = computed(function () {
  const date = now.value
  return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`
})

const weekdayText = computed(function () {
  const weekNames = ['星期日', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六']
  return weekNames[now.value.getDay()]
})

const greetingText = computed(function () {
  const hour = now.value.getHours()
  if (hour < 6) return '夜深了，注意休息'
  if (hour < 12) return '早上好，开始今天的安排'
  if (hour < 18) return '下午好，继续保持节奏'
  return '晚上好，记得整理今天的事项'
})

function tickNow() {
  now.value = new Date()
}

onMounted(function () {
  tickNow()
  clockTimerId = window.setInterval(tickNow, 1000)
})

onBeforeUnmount(function () {
  if (clockTimerId !== null) {
    window.clearInterval(clockTimerId)
    clockTimerId = null
  }
})
</script>

<template>
  <div class="status-container">
    <div class="status-header">
      <div>
        <h2 class="status-title">Hello！</h2>
        <div class="status-subtitle">{{ greetingText }}</div>
      </div>
      <span class="status-chip">实时</span>
    </div>

    <div class="status-panel time-panel">
      <div class="time-text">{{ timeText }}</div>
      <div class="panel-meta">{{ dateText }} · {{ weekdayText }}</div>
    </div>
  </div>
</template>

<style scoped>
.status-container {
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 18px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
}

.status-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  gap: 12px;
}

.status-title {
  color: white;
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0 0 4px;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.status-subtitle {
  color: rgba(255, 255, 255, 0.65);
  font-size: 0.82rem;
  text-align: left;
}

.status-chip {
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.9rem;
  font-weight: 400;
  background: rgba(255, 255, 255, 0.1);
  padding: 4px 12px;
  border-radius: 12px;
  flex-shrink: 0;
}

.status-panel {
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 12px;
  padding: 14px;
  text-align: left;
}

.panel-label {
  color: rgba(255, 255, 255, 0.55);
  font-size: 0.78rem;
  margin-bottom: 8px;
}

.time-text {
  color: white;
  font-size: 2rem;
  font-weight: 700;
  letter-spacing: 1px;
  line-height: 1.1;
  margin-bottom: 6px;
}

.panel-meta {
  color: rgba(255, 255, 255, 0.72);
  font-size: 0.85rem;
}

@media (max-width: 768px) {
  .status-container {
    padding: 14px;
  }

  .time-text {
    font-size: 1.7rem;
  }

  .status-chip {
    font-size: 0.8rem;
  }
}
</style>

<script setup>
import { onBeforeUnmount, onMounted, ref } from 'vue'
import TodoPanel from './features/todo/TodoPanel.vue'
import FileTransfer from './features/transfer/FileTransfer.vue'

// 球体位置和大小数据
const spheres = ref([
  { top: '10%', left: '15%', size: '80px', color: 'rgba(138, 43, 226, 0.3)', animation: 'float 8s ease-in-out infinite' },
  { top: '20%', right: '10%', size: '120px', color: 'rgba(255, 107, 107, 0.25)', animation: 'float 12s ease-in-out infinite reverse' },
  { top: '60%', left: '20%', size: '60px', color: 'rgba(0, 206, 209, 0.2)', animation: 'float 10s ease-in-out infinite' },
  { bottom: '15%', right: '25%', size: '90px', color: 'rgba(255, 215, 0, 0.25)', animation: 'float 14s ease-in-out infinite reverse' },
  { top: '40%', right: '35%', size: '50px', color: 'rgba(144, 238, 144, 0.2)', animation: 'float 7s ease-in-out infinite' },
  { bottom: '25%', left: '30%', size: '70px', color: 'rgba(255, 192, 203, 0.25)', animation: 'float 9s ease-in-out infinite reverse' }
])
const mouseX = ref(0)
const mouseY = ref(0)
const appContainer = ref(null)
const contentLayer = ref(null)

function getEntranceElements() {
  return [appContainer.value, contentLayer.value].filter(Boolean)
}

function prepareEntranceAnimation() {
  getEntranceElements().forEach(function (element) {
    element.classList.add('entrance-ready')
    element.classList.remove('entrance-active')
  })
}

function playEntranceAnimation() {
  prepareEntranceAnimation()
  requestAnimationFrame(function () {
    requestAnimationFrame(function () {
      getEntranceElements().forEach(function (element) {
        element.classList.add('entrance-active')
        element.classList.remove('entrance-ready')
      })
    })
  })
}

onMounted(function () {
  window.prepareEntranceAnimation = prepareEntranceAnimation
  window.playEntranceAnimation = playEntranceAnimation
  playEntranceAnimation()
})

onBeforeUnmount(function () {
  if (window.prepareEntranceAnimation === prepareEntranceAnimation) {
    delete window.prepareEntranceAnimation
  }
  if (window.playEntranceAnimation === playEntranceAnimation) {
    delete window.playEntranceAnimation
  }
})

</script>

<template>
  <div ref="appContainer" class="app-container entrance-target">
    <!-- 背景层 -->
    <div class="background-layer" :style="{ transform: `translate(${mouseX}px, ${mouseY}px)` }">
      <!-- 渐变背景 -->
      <div class="gradient-bg"></div>
      
      <!-- 装饰球体 -->
      <div 
        v-for="(sphere, index) in spheres" 
        :key="index"
        class="decorative-sphere"
        :style="{
          top: sphere.top,
          left: sphere.left,
          right: sphere.right,
          bottom: sphere.bottom,
          width: sphere.size,
          height: sphere.size,
          backgroundColor: sphere.color,
          animation: sphere.animation
        }"
      ></div>
    </div>
    
    <!-- 内容层 -->
    <div ref="contentLayer" class="content-layer entrance-target entrance-delay">
      <!-- 待办事项模块 -->
      <div class="module-wrapper">
        <TodoPanel />
      </div>

      <!-- 文件中转模块 -->
      <div class="module-wrapper">
        <FileTransfer />
      </div>
    </div>
  </div>
</template>

<style scoped>

/* 主容器 - 关键：box-sizing: border-box 避免边框导致尺寸溢出 */
.app-container {
  width: 100%;
  height: 100%;
  overflow: hidden;
  position: absolute;
  top: 0;
  left: 0;
  box-sizing: border-box;
  font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
  border-radius: 20px;
}

/* 背景层 */
.background-layer {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  transition: transform 0.3s ease-out;
  z-index: 0;
}

/* 渐变背景 */
.gradient-bg {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  backdrop-filter: blur(8px);
}

/* 装饰球体 */
.decorative-sphere {
  position: absolute;
  border-radius: 50%;
  filter: blur(25px);
  opacity: 0.8;
  transition: transform 0.3s ease-out;
}

/* 球体浮动动画 */
@keyframes float {
  0%, 100% {
    transform: translateY(0px) scale(1);
  }
  50% {
    transform: translateY(-30px) scale(1.1);
  }
}

/* 内容层 - 充满容器（减去边框），仅内部滚动 */
.content-layer {
  position: relative;
  z-index: 1;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  justify-content: flex-start;
  align-items: center;
  color: white;
  text-align: center;
  padding: 8px 8px;
  box-sizing: border-box;
  overflow-y: auto;
}

/* 自定义内容层滚动条 */
.content-layer::-webkit-scrollbar {
  width: 6px;
}
.content-layer::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 3px;
}
.content-layer::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
  transition: background 0.3s ease;
}
.content-layer::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.module-wrapper {
  width: 100%;
  max-width: 600px;
  margin-bottom: 14px;
  box-sizing: border-box;
}

/* 功能占位符 */
.feature-placeholder {
  padding: 3rem 4rem;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 20px;
  backdrop-filter: blur(10px);
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  box-sizing: border-box;
}

.feature-placeholder p {
  font-size: 1.1rem;
  color: rgba(255, 255, 255, 0.9);
  margin: 0;
}

.entrance-target {
  opacity: 1;
  transform: translateX(0);
  transition: opacity 0.28s ease, transform 0.28s ease;
  will-change: opacity, transform;
}

.entrance-delay {
  transition-delay: 0.06s;
}

.entrance-ready {
  opacity: 0;
  transform: translateX(-18px);
}

.entrance-active {
  opacity: 1;
  transform: translateX(0);
}
</style>

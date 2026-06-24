<script setup>
/**
 * pyislandLOGO.vue - Pyisland LOGO组件
 * 展示带有旋转动画效果的Pyisland标志，由多层logo叠加组成
 */

// 导入logo图片资源
import pyislandImg from '../assets/PyislandLogo单胶囊.png'
</script>

<template>
  <div class="logos-container">
    <img :src="pyislandImg" class="rotating-logo logo" alt="Pyisland-logo" />
    <img :src="pyislandImg" class="rotating-logo logo1" alt="Pyisland-logo" />
    <img :src="pyislandImg" class="rotating-logo logo2" alt="Pyisland-logo" />
    <img :src="pyislandImg" class="rotating-logo logo3" alt="Pyisland-logo" />
    <img :src="pyislandImg" class="rotating-logo logo4" alt="Pyisland-logo" />
  </div>
</template>

<style scoped>

.logos-container {
  position: relative;
  width: 500px;
  height: 500px;
  display: flex;
  justify-content: center;
  align-items: center;
}

.rotating-logo {
  position: absolute;
}

.logo {
  width: 100%;  /* 改为100% */
  height: 100%; /* 改为100% */
  animation: rotate 3s ease-in-out 0.5s infinite normal forwards;
}

.logo1 {
  width: 100%;  /* 改为100% */
  height: 100%; /* 改为100% */
  animation: rotate1 3s ease-in-out 0.5s infinite normal forwards;
}

.logo2 {
  width: 100%;  /* 改为100% */
  height: 100%; /* 改为100% */
  animation: rotate2 3s ease-in-out 0.5s infinite normal forwards;
}

.logo3 {
  width: 100%;  /* 改为100% */
  height: 100%; /* 改为100% */
  animation: rotate3 3s ease-in-out 0.5s infinite normal forwards;
}

.logo4 {
  width: 100%;  /* 改为100% */
  height: 100%; /* 改为100% */
  animation: rotate4 3s ease-in-out 0.5s infinite normal forwards;
}


/* Keyframes - 三个阶段: 0-33.33%旋转, 33.33%-66.66%停留, 66.66%-100%继续旋转到-360度 */
@keyframes rotate {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(0deg); }
  75% { transform: rotate(0deg); }
  100% { transform: rotate(-360deg); }
}
@keyframes rotate1 {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(-72deg); }
  75% { transform: rotate(-72deg); }
  100% { transform: rotate(-360deg); }
}
@keyframes rotate2 {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(-144deg); }
  75% { transform: rotate(-144deg); }
  100% { transform: rotate(-360deg); }
}
@keyframes rotate3 {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(-216deg); }
  75% { transform: rotate(-216deg); }
  100% { transform: rotate(-360deg); }
}
@keyframes rotate4 {
  0% { transform: rotate(0deg); }
  50% { transform: rotate(-288deg); }
  75% { transform: rotate(-288deg); }
  100% { transform: rotate(-360deg); }
}

</style>
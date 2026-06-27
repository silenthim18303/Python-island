<script setup>
import { onMounted, ref } from 'vue'
import PyislandLOGO from '../../components/pyislandLOGO.vue'
import { Github } from '@icon-park/vue-next'
import { Tiktok } from '@icon-park/vue-next'

const websiteUrl = 'http://silenthim.top/'
const websiteUrl2 = 'https://pyisland.com/'

const githubUrl = 'https://github.com/Python-island/Python-island'
const douyinUrl = 'https://www.douyin.com/video/7653817032713981220'

function openLink(url) {
  window.location.href = `pyisland://open_url?url=${encodeURIComponent(url)}`
}
</script>

<template>
  <div class="wait-container">
    <div class="wait-upper-section">
      <div class="wait-logo">
        <PyislandLOGO />
      </div>

      <div class="wait-content">
        <h3 class="wait-title">更多功能正在开发中</h3>
        <p class="wait-description">
          PyIsland_SideV 正在持续完善中。您可以通过下面的方式支持我们
        </p>
      </div>
    </div>

    <div class="wait-actions">
      <button class="wait-button wait-button-text" type="button" @click="openLink(websiteUrl)" aria-label="打开官网">
          <div class="wait-logo2">
              <PyislandLOGO />P
          </div>
      </button>
      <button class="wait-button wait-button-text" type="button" @click="openLink(websiteUrl2)" aria-label="打开官网">
          <div class="wait-logo2">
              <PyislandLOGO />E
          </div>
      </button>
      <button class="wait-button" type="button" @click="openLink(githubUrl)" aria-label="打开 GitHub">
        <Github theme="outline" size="22" fill="currentColor" />
      </button>
      <button class="wait-button" type="button" @click="openLink(douyinUrl)" aria-label="打开抖音">
        <Tiktok theme="outline" size="22" fill="currentColor" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.wait-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 14px;
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 16px 18px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
  min-height: 154px;
}

.wait-upper-section {
  display: flex;
  align-items: center;
  gap: 14px;
  width: 100%;
}

.wait-logo {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 120px;
  min-width: 120px;
  height: 120px;
  overflow: hidden;
  flex-shrink: 0;
}

.wait-logo :deep(.logos-container) {
  width: 120px;
  height: 120px;
}

.wait-logo2 {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  min-width: 30px;
  height: 30px;
  overflow: hidden;
  flex-shrink: 0;
}

.wait-logo2 :deep(.logos-container) {
  width: 30px;
  height: 30px;
}

.wait-content {
  text-align: left;
  min-width: 0;
}

.wait-title {
  margin: 0 0 8px;
  color: white;
  font-size: 1.08rem;
  font-weight: 600;
  line-height: 1.3;
}

.wait-description {
  margin: 0;
  color: rgba(255, 255, 255, 0.72);
  font-size: 0.84rem;
  line-height: 1.6;
}

.wait-actions {
  display: flex;
  gap: 10px;
  justify-content: center;
  width: 100%;
}

.wait-button {
  width: 42px;
  height: 42px;
  padding: 0;
  border-radius: 50%;
  border: 1px solid rgba(255, 255, 255, 0.16);
  background: rgba(255, 255, 255, 0.08);
  color: white;
  cursor: pointer;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s ease, transform 0.2s ease, border-color 0.2s ease;
}

.wait-button:hover {
  background: rgba(255, 255, 255, 0.16);
  border-color: rgba(255, 255, 255, 0.28);
  transform: translateY(-1px);
}

.wait-button-text {
  font-size: 0.72rem;
  font-weight: 600;
}

</style>

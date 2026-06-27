<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const MAX_IMAGE_SIZE = 50 * 1024 * 1024
const MAX_IMAGE_SIZE_LABEL = '50 MB'

const items = ref([])
const isDragging = ref(false)
const saveMessage = ref('拖拽文件或图片到此处')

// --- IndexedDB 本地存储 ---

const DB_NAME = 'PyIslandTransferDB'
const STORE_NAME = 'transfer_items'
const DB_VERSION = 1

function initDB() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION)
    
    request.onerror = () => reject(request.error)
    
    request.onsuccess = () => resolve(request.result)
    
    request.onupgradeneeded = (event) => {
      const db = event.target.result
      if (!db.objectStoreNames.contains(STORE_NAME)) {
        db.createObjectStore(STORE_NAME, { keyPath: 'id' })
      }
    }
  })
}

async function loadItems() {
  try {
    const db = await initDB()
    const transaction = db.transaction(STORE_NAME, 'readonly')
    const store = transaction.objectStore(STORE_NAME)
    const request = store.getAll()
    
    request.onsuccess = () => {
      // 按照时间倒序排列（最新的在前面）
      items.value = request.result.sort((a, b) => b.timestamp - a.timestamp)
    }
  } catch (error) {
    console.error('[transfer] 从 IndexedDB 加载数据失败:', error)
  }
}

async function saveItemToDB(item) {
  try {
    const db = await initDB()
    const transaction = db.transaction(STORE_NAME, 'readwrite')
    const store = transaction.objectStore(STORE_NAME)
    store.put(item)
  } catch (error) {
    console.error('[transfer] 保存数据到 IndexedDB 失败:', error)
  }
}

async function removeItemFromDB(id) {
  try {
    const db = await initDB()
    const transaction = db.transaction(STORE_NAME, 'readwrite')
    const store = transaction.objectStore(STORE_NAME)
    store.delete(id)
  } catch (error) {
    console.error('[transfer] 从 IndexedDB 删除数据失败:', error)
  }
}

async function clearDB() {
  try {
    const db = await initDB()
    const transaction = db.transaction(STORE_NAME, 'readwrite')
    const store = transaction.objectStore(STORE_NAME)
    store.clear()
  } catch (error) {
    console.error('[transfer] 清空 IndexedDB 失败:', error)
  }
}

// --- 初始化与通信 ---

function initBridge() {
  // 接收来自 PySide6 的原生文件拖拽路径
  window.handleNativeFileDrop = function (localPaths) {
    if (!Array.isArray(localPaths)) return
    
    const timestamp = Date.now()
    const newItems = localPaths.map((path, index) => {
      const item = {
        id: timestamp + index + Math.random().toString(36).substr(2, 9),
        type: 'file',
        path: path,
        name: path.split('\\').pop().split('/').pop(),
        timestamp: timestamp + index
      }
      saveItemToDB(item)
      return item
    })
    
    items.value = [...newItems, ...items.value]
  }
  
  resetSaveMessage()
}

// --- 拖拽处理 (HTML5) ---

function handleDragOver(event) {
  event.preventDefault()
  isDragging.value = true
}

function handleDragLeave() {
  isDragging.value = false
}

function handleDrop(event) {
  event.preventDefault()
  isDragging.value = false
  
  const files = event.dataTransfer.files
  if (files && files.length > 0) {
    handleImageFiles(Array.from(files))
  }
}

function handleImageFiles(fileList) {
  const imageFiles = fileList.filter(f => f.type.startsWith('image/'))
  
  if (imageFiles.length === 0) {
    // 非图片文件由 PySide6 的 dropEvent 拦截处理，这里忽略
    return
  }

  for (const file of imageFiles) {
    if (file.size > MAX_IMAGE_SIZE) {
      saveMessage.value = `${file.name} 超过 ${MAX_IMAGE_SIZE_LABEL}`
      continue
    }

    const reader = new FileReader()
    reader.onload = (e) => {
      const item = {
        id: Date.now() + Math.random().toString(36).substr(2, 9),
        type: 'image',
        src: e.target.result,
        timestamp: Date.now()
      }
      items.value.unshift(item)
      saveItemToDB(item)
      resetSaveMessage()
    }
    reader.readAsDataURL(file)
  }
}

// --- 交互操作 ---

function removeItem(id) {
  items.value = items.value.filter(item => item.id !== id)
  removeItemFromDB(id)
}

function clearAll() {
  items.value = []
  clearDB()
}

function openItem(item) {
  if (item.type === 'file') {
    // 使用自定义协议调用后端
    window.location.href = `pyisland://open_file?path=${encodeURIComponent(item.path)}`
  } else if (item.type === 'image') {
    // 使用自定义协议调用后端
    window.location.href = `pyisland://open_image?src=${encodeURIComponent(item.src)}`
  }
}

function resetSaveMessage() {
  saveMessage.value = '拖拽文件或图片到此处'
}

// --- 生命周期 ---

onMounted(() => {
  loadItems() // 组件挂载时立即从 IndexedDB 加载数据
  initBridge()
  
  // 监听全局粘贴事件，支持粘贴图片
  window.addEventListener('paste', handlePaste)
})

onBeforeUnmount(() => {
  window.removeEventListener('paste', handlePaste)
})

function handlePaste(event) {
  const items = (event.clipboardData || event.originalEvent.clipboardData).items
  const imageFiles = []
  for (const item of items) {
    if (item.type.indexOf('image') === 0) {
      imageFiles.push(item.getAsFile())
    }
  }
  if (imageFiles.length > 0) {
    handleImageFiles(imageFiles)
  }
}

const totalCount = computed(() => items.value.length)

</script>

<template>
  <div class="transfer-container">
    <div class="transfer-header">
      <h2 class="transfer-title">速记中转</h2>
      <span class="file-count">{{ totalCount }} 个项目</span>
    </div>

    <div
      class="drop-zone"
      :class="{ 'is-dragging': isDragging }"
      @drop="handleDrop"
      @dragover="handleDragOver"
      @dragleave="handleDragLeave"
    >
      <div class="drop-icon">+</div>
      <div class="drop-text">拖拽文件/图片到此处，或直接粘贴图片</div>
      <div class="drop-hint">{{ saveMessage }}</div>
    </div>

    <div class="item-list" v-if="items.length > 0">
      <div
        v-for="item in items"
        :key="item.id"
        class="list-item"
        @click="openItem(item)"
      >
        <!-- 文件类型 -->
        <template v-if="item.type === 'file'">
          <div class="item-icon icon-file">FILE</div>
          <div class="item-info">
            <div class="item-name" :title="item.path">{{ item.name }}</div>
            <div class="item-meta">点击在文件夹中显示</div>
          </div>
        </template>

        <!-- 图片类型 -->
        <template v-else-if="item.type === 'image'">
          <div class="item-image-wrapper">
            <img :src="item.src" class="item-image" draggable="true" />
          </div>
        </template>

        <button @click.stop="removeItem(item.id)" class="remove-btn">x</button>
      </div>
    </div>

    <div v-else class="empty-state">
      <p>暂无内容，开始拖拽吧</p>
    </div>

    <div class="transfer-footer" v-if="items.length > 0">
      <button @click="clearAll" class="clear-btn">清空全部</button>
    </div>
  </div>
</template>

<style scoped>
.transfer-container {
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 18px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.transfer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
}

.transfer-title {
  color: white;
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.file-count {
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.9rem;
  font-weight: 400;
  background: rgba(255, 255, 255, 0.1);
  padding: 4px 12px;
  border-radius: 12px;
}

.drop-zone {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 16px 14px;
  border: 2px dashed rgba(255, 255, 255, 0.2);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.03);
  transition: all 0.3s ease;
  margin-bottom: 10px;
  flex-shrink: 0;
}

.drop-zone.is-dragging {
  border-color: rgba(120, 120, 120, 0.7);
  background: rgba(255, 255, 255, 0.08);
  transform: scale(1.01);
}

.drop-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.15);
  color: rgba(255, 255, 255, 0.8);
  font-size: 1.3rem;
  font-weight: 300;
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 6px;
  line-height: 1;
}

.drop-text {
  color: rgba(255, 255, 255, 0.85);
  font-size: 0.9rem;
  margin-bottom: 2px;
}

.drop-hint {
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.75rem;
}

.item-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 4px;
  flex-grow: 1;
}

.item-list::-webkit-scrollbar {
  width: 6px;
}

.item-list::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 3px;
}

.item-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
}

.list-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  transition: all 0.2s ease;
  border: 1px solid rgba(255, 255, 255, 0.1);
  gap: 10px;
  cursor: pointer;
  position: relative;
}

.list-item:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: translateX(2px);
}

.item-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.15);
  flex-shrink: 0;
  font-size: 0.7rem;
  color: rgba(255, 255, 255, 0.8);
  font-weight: bold;
}

.item-info {
  flex: 1;
  min-width: 0;
  overflow: hidden;
}

.item-name {
  color: white;
  font-size: 0.9rem;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-bottom: 4px;
}

.item-meta {
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.75rem;
}

.item-image-wrapper {
  width: 100%;
  display: flex;
  justify-content: center;
  background: rgba(0, 0, 0, 0.2);
  border-radius: 6px;
  overflow: hidden;
}

.item-image {
  max-width: 100%;
  max-height: 60px;
  object-fit: contain;
  cursor: grab;
}

.remove-btn {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  width: 24px;
  height: 24px;
  border: none;
  border-radius: 12px;
  background: rgba(255, 107, 107, 0.2);
  color: rgba(255, 107, 107, 0.9);
  font-size: 0.9rem;
  cursor: pointer;
  opacity: 0;
  transition: all 0.2s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.list-item:hover .remove-btn {
  opacity: 1;
}

.remove-btn:hover {
  background: rgba(255, 107, 107, 0.4);
  color: white;
}

.empty-state {
  text-align: center;
  padding: 30px 12px;
  color: rgba(255, 255, 255, 0.5);
  font-size: 0.9rem;
  flex-grow: 1;
  display: flex;
  align-items: center;
  justify-content: center;
}

.transfer-footer {
  display: flex;
  justify-content: flex-end;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
  margin-top: 10px;
}

.clear-btn {
  padding: 6px 14px;
  border: none;
  border-radius: 8px;
  background: rgba(255, 107, 107, 0.15);
  color: rgba(255, 255, 255, 0.8);
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.clear-btn:hover {
  background: rgba(255, 107, 107, 0.3);
  color: white;
}
</style>

<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue'

const MAX_FILE_SIZE = 50 * 1024 * 1024
const MAX_FILE_SIZE_LABEL = '50 MB'

const files = ref([])
const isDragging = ref(false)
const fileInput = ref(null)
const transferDirectory = ref('')
const saveMessage = ref('文件将保存到本地中转目录')
let backend = null

function getDefaultMessage() {
  if (transferDirectory.value) {
    return `文件将保存到 ${transferDirectory.value}，单个文件不超过 ${MAX_FILE_SIZE_LABEL}`
  }
  return `仅支持文件上传，单个文件不超过 ${MAX_FILE_SIZE_LABEL}`
}

function resetSaveMessage() {
  saveMessage.value = getDefaultMessage()
}

function hydrateFiles(payload) {
  try {
    const parsed = JSON.parse(payload || '[]')
    if (!Array.isArray(parsed)) {
      files.value = []
      return
    }
    files.value = parsed
      .filter(function (entry) { return entry && typeof entry === 'object' })
      .map(function (entry) {
        return {
          id: typeof entry.id === 'string' ? entry.id : String(entry.id || Date.now()),
          name: typeof entry.name === 'string' ? entry.name : '',
          size: Number(entry.size) || 0,
          type: typeof entry.type === 'string' ? entry.type : '',
          addedAt: Number(entry.addedAt) || Date.now(),
          status: typeof entry.status === 'string' ? entry.status : 'ready'
        }
      })
  } catch (error) {
    console.error('[transfer] 解析后端数据失败:', error)
  }
}

function formatSize(bytes) {
  if (!bytes || bytes <= 0) return '0 B'
  const units = ['B', 'KB', 'MB', 'GB', 'TB']
  let size = bytes
  let unitIndex = 0
  while (size >= 1024 && unitIndex < units.length - 1) {
    size /= 1024
    unitIndex++
  }
  return `${size.toFixed(size >= 10 ? 0 : 1)} ${units[unitIndex]}`
}

function formatTime(timestamp) {
  const d = new Date(timestamp)
  const pad = function (n) { return n < 10 ? '0' + n : n }
  return `${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`
}

function getFileIcon(fileType) {
  const t = (fileType || '').toLowerCase()
  if (t.startsWith('image/')) return 'image'
  if (t.startsWith('video/')) return 'video'
  if (t.startsWith('audio/')) return 'audio'
  if (t.includes('pdf')) return 'pdf'
  if (t.includes('zip') || t.includes('rar') || t.includes('7z') || t.includes('tar')) return 'archive'
  if (t.includes('text') || t.includes('json') || t.includes('xml') || t.includes('markdown')) return 'text'
  return 'file'
}

function handleFileSelect(event) {
  const selected = event.target.files
  if (selected && selected.length > 0) {
    importFiles(Array.from(selected))
  }
  if (fileInput.value) fileInput.value.value = ''
}

function handleDrop(event) {
  event.preventDefault()
  isDragging.value = false
  const items = Array.from((event.dataTransfer && event.dataTransfer.items) || [])
  const hasDirectory = items.some(function (item) {
    if (item.kind !== 'file' || typeof item.webkitGetAsEntry !== 'function') {
      return false
    }
    const entry = item.webkitGetAsEntry()
    return Boolean(entry && entry.isDirectory)
  })
  if (hasDirectory) {
    saveMessage.value = '不支持直接拖入文件夹'
    return
  }
  // 在桌面端优先使用 PySide6 原生拖拽路径，避免和前端文件读取重复导入。
  if (backend && typeof backend.importPaths === 'function') {
    return
  }
  const dropped = event.dataTransfer && event.dataTransfer.files
  if (dropped && dropped.length > 0) {
    importFiles(Array.from(dropped))
  }
}

function handleDragOver(event) {
  event.preventDefault()
  isDragging.value = true
}

function handleDragLeave() {
  isDragging.value = false
}

function parseJsonPayload(payload, fallback) {
  try {
    return JSON.parse(payload)
  } catch (_error) {
    return fallback
  }
}

function consumeImportResult(payload) {
  const result = parseJsonPayload(payload, { files: [], errors: [] })
  if (Array.isArray(result.errors) && result.errors.length > 0) {
    saveMessage.value = result.errors[0]
  } else {
    resetSaveMessage()
  }
  refreshFiles()
}

function initBridge() {
  if (typeof qt === 'undefined' || !qt.webChannelTransport || typeof QWebChannel !== 'function') {
    saveMessage.value = '当前未连接 PySide6 后端'
    return
  }
  new QWebChannel(qt.webChannelTransport, function (channel) {
    backend = channel.objects.fileTransferBackend
    if (!backend) {
      saveMessage.value = '未找到文件中转后端'
      return
    }

    backend.transferDirectory(function (directory) {
      transferDirectory.value = directory || ''
      resetSaveMessage()
    })
    refreshFiles()
    window.handleNativeFileDrop = function (localPaths) {
      importPaths(localPaths)
    }
  })
}

function refreshFiles() {
  if (!backend || typeof backend.listFiles !== 'function') {
    files.value = []
    return
  }
  backend.listFiles(function (payload) {
    hydrateFiles(payload)
  })
}

function openNativePicker() {
  if (backend && typeof backend.selectFiles === 'function') {
    backend.selectFiles(function (payload) {
      consumeImportResult(payload)
    })
    return
  }
  if (fileInput.value) {
    fileInput.value.click()
  }
}

function importPaths(localPaths) {
  if (!backend || typeof backend.importPaths !== 'function') {
    return
  }
  const payload = JSON.stringify(Array.isArray(localPaths) ? localPaths : [])
  backend.importPaths(payload, function (response) {
    consumeImportResult(response)
  })
}

function readFileAsDataUrl(file) {
  return new Promise(function (resolve, reject) {
    const reader = new FileReader()
    reader.onload = function () {
      resolve(String(reader.result || ''))
    }
    reader.onerror = function () {
      reject(reader.error || new Error('读取文件失败'))
    }
    reader.readAsDataURL(file)
  })
}

async function importFiles(fileList) {
  if (!backend || typeof backend.uploadFile !== 'function') {
    saveMessage.value = '后端未连接，无法导入文件'
    return
  }

  const rejected = []
  const allowedFiles = []
  for (const file of fileList) {
    if (file.size > MAX_FILE_SIZE) {
      rejected.push(`${file.name}: 单个文件不能超过 ${MAX_FILE_SIZE_LABEL}`)
      continue
    }
    allowedFiles.push(file)
  }

  if (allowedFiles.length === 0) {
    saveMessage.value = rejected[0] || `仅支持不超过 ${MAX_FILE_SIZE_LABEL} 的文件`
    return
  }

  const uploadErrors = []

  for (const file of allowedFiles) {
    try {
      const dataUrl = await readFileAsDataUrl(file)
      const payload = JSON.stringify({
        name: file.name,
        size: file.size || 0,
        type: file.type || '',
        kind: 'file',
        dataUrl: dataUrl
      })
      await new Promise(function (resolve, reject) {
        backend.uploadFile(payload, function (response) {
          const result = parseJsonPayload(response, { ok: false, error: '上传失败' })
          if (result && result.ok) {
            resolve()
            return
          }
          reject(new Error(result.error || '上传失败'))
        })
      })
    } catch (error) {
      console.error('[transfer] 导入文件失败:', error)
      uploadErrors.push(`${file.name}: ${error.message || '上传失败'}`)
    }
  }

  refreshFiles()
  if (uploadErrors.length > 0) {
    saveMessage.value = uploadErrors[0]
  } else if (rejected.length > 0) {
    saveMessage.value = rejected[0]
  } else {
    resetSaveMessage()
  }
}

function removeFile(fileId) {
  if (!backend || typeof backend.removeFile !== 'function') {
    return
  }
  backend.removeFile(fileId, function (payload) {
    const result = parseJsonPayload(payload, { ok: false, error: '删除失败' })
    if (result.ok) {
      resetSaveMessage()
      refreshFiles()
      return
    }
    saveMessage.value = result.error || '删除失败'
  })
}

function copyFile(fileId, fileName) {
  if (!backend || typeof backend.copyFileToClipboard !== 'function') {
    saveMessage.value = '当前后端不支持复制到剪切板'
    return
  }
  backend.copyFileToClipboard(fileId, function (payload) {
    const result = parseJsonPayload(payload, { ok: false, error: '复制失败' })
    if (result.ok) {
      saveMessage.value = `已复制 ${fileName} 到剪切板`
      return
    }
    saveMessage.value = result.error || '复制失败'
  })
}

function clearAll() {
  if (!backend || typeof backend.clearFiles !== 'function') {
    return
  }
  backend.clearFiles(function (payload) {
    const result = parseJsonPayload(payload, { ok: false, errors: ['清空失败'] })
    if (result.ok) {
      resetSaveMessage()
    } else if (Array.isArray(result.errors) && result.errors.length > 0) {
      saveMessage.value = result.errors[0]
    } else {
      saveMessage.value = '清空失败'
    }
    refreshFiles()
  })
}

function openTransferDirectory() {
  if (!backend || typeof backend.openTransferDirectory !== 'function') {
    return
  }
  backend.openTransferDirectory(function () {})
}

function revealFile(fileId) {
  if (!backend || typeof backend.openFileLocation !== 'function') {
    return
  }
  backend.openFileLocation(fileId, function () {})
}

onMounted(function () {
  initBridge()
})

onBeforeUnmount(function () {
  if (window.handleNativeFileDrop) {
    delete window.handleNativeFileDrop
  }
})

const totalSize = computed(function () {
  return files.value.reduce(function (sum, f) { return sum + f.size }, 0)
})

const totalCount = computed(function () {
  return files.value.length
})
</script>

<template>
  <div class="transfer-container">
    <div class="transfer-header">
      <h2 class="transfer-title">文件中转</h2>
      <span class="file-count">{{ totalCount }} 个文件 · {{ formatSize(totalSize) }}</span>
    </div>

    <div
      class="drop-zone"
      :class="{ 'is-dragging': isDragging }"
      @drop="handleDrop"
      @dragover="handleDragOver"
      @dragleave="handleDragLeave"
      @click="openNativePicker"
    >
      <input
        ref="fileInput"
        type="file"
        multiple
        class="file-input"
        @change="handleFileSelect"
      />
      <div class="drop-icon">+</div>
      <div class="drop-text">拖拽文件到此处，或点击选择</div>
      <div class="drop-hint">{{ saveMessage }}</div>
    </div>

    <div class="file-list" v-if="files.length > 0">
      <div
        v-for="file in files"
        :key="file.id"
        class="file-item"
      >
        <div class="file-icon" :class="'icon-' + getFileIcon(file.type)">
          <span class="icon-label">{{ getFileIcon(file.type) === 'image' ? 'IMG' : getFileIcon(file.type) === 'video' ? 'VID' : getFileIcon(file.type) === 'audio' ? 'AUD' : getFileIcon(file.type) === 'pdf' ? 'PDF' : getFileIcon(file.type) === 'archive' ? 'ZIP' : getFileIcon(file.type) === 'text' ? 'TXT' : 'FILE' }}</span>
        </div>
        <div class="file-info">
          <button @click.stop="revealFile(file.id)" class="file-link">{{ file.name }}</button>
          <div class="file-meta">{{ formatSize(file.size) }} · {{ formatTime(file.addedAt) }}</div>
        </div>
        <button @click.stop="copyFile(file.id, file.name)" class="copy-btn">复制</button>
        <button @click.stop="removeFile(file.id)" class="remove-btn">x</button>
      </div>
    </div>

    <div v-else class="empty-state">
      <p>暂无中转文件，添加文件开始使用</p>
    </div>

    <div class="transfer-footer" v-if="files.length > 0">
      <button @click="openTransferDirectory" class="folder-btn">打开目录</button>
      <button @click="clearAll" class="clear-btn">清空列表</button>
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
}

.transfer-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
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
  cursor: pointer;
  transition: all 0.3s ease;
  margin-bottom: 10px;
  position: relative;
}

.drop-zone:hover {
  border-color: rgba(255, 255, 255, 0.35);
  background: rgba(255, 255, 255, 0.05);
}

.drop-zone.is-dragging {
  border-color: rgba(120, 120, 120, 0.7);
  background: rgba(255, 255, 255, 0.08);
  transform: scale(1.01);
}

.file-input {
  display: none;
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

.file-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  max-height: 22vh;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 4px;
  box-sizing: border-box;
  margin-bottom: 10px;
}

.file-list::-webkit-scrollbar {
  width: 6px;
}

.file-list::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 3px;
}

.file-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
}

.file-list::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.file-list {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.2) rgba(255, 255, 255, 0.05);
}

.file-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  transition: all 0.3s ease;
  border: 1px solid rgba(255, 255, 255, 0.1);
  gap: 10px;
}

.file-item:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: translateX(4px);
}

.file-icon {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.1);
  flex-shrink: 0;
}

.icon-label {
  font-size: 0.65rem;
  color: rgba(255, 255, 255, 0.75);
  font-weight: 600;
  letter-spacing: 0.5px;
}

.file-info {
  flex: 1;
  min-width: 0;
  text-align: left;
}

.file-link {
  color: white;
  font-size: 0.85rem;
  background: transparent;
  border: none;
  padding: 0;
  cursor: pointer;
  text-align: left;
  width: 100%;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-bottom: 2px;
}

.file-link:hover {
  color: rgba(255, 255, 255, 0.82);
}

.file-meta {
  color: rgba(255, 255, 255, 0.55);
  font-size: 0.75rem;
}

.copy-btn,
.remove-btn {
  padding: 4px 8px;
  border: none;
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.1);
  color: rgba(255, 255, 255, 0.65);
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.3s ease;
  opacity: 0;
  flex-shrink: 0;
}

.file-item:hover .copy-btn,
.file-item:hover .remove-btn {
  opacity: 1;
}

.copy-btn:hover {
  background: rgba(255, 255, 255, 0.18);
  color: rgba(255, 255, 255, 0.92);
  transform: scale(1.05);
}

.remove-btn:hover {
  background: rgba(255, 107, 107, 0.2);
  color: rgba(255, 107, 107, 0.9);
  transform: scale(1.1);
}

.empty-state {
  text-align: center;
  padding: 20px 12px;
  color: rgba(255, 255, 255, 0.6);
  font-size: 0.9rem;
}

.empty-state p {
  margin: 0;
}

.transfer-footer {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
  padding-top: 10px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.folder-btn,
.clear-btn {
  padding: 6px 12px;
  border: none;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.1);
  color: rgba(255, 255, 255, 0.75);
  font-size: 0.8rem;
  cursor: pointer;
  transition: all 0.3s ease;
}

.folder-btn:hover,
.clear-btn:hover {
  background: rgba(255, 107, 107, 0.15);
  color: rgba(255, 255, 255, 0.9);
}

@media (max-width: 768px) {
  .transfer-container {
    padding: 14px;
  }

  .transfer-title {
    font-size: 1.15rem;
  }

  .drop-zone {
    padding: 14px 12px;
  }

  .file-link {
    font-size: 0.8rem;
  }
}
</style>

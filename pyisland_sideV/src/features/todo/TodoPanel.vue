<script setup>
import { computed, ref } from 'vue'

const STORAGE_KEY = 'pyisland.todo.tasks'

const newTask = ref('')
const saveMessage = ref('本地自动保存')
const tasks = ref(loadTasks())

const pendingCount = computed(function () {
  return tasks.value.filter(function (task) {
    return !task.completed
  }).length
})

function loadTasks() {
  try {
    const payload = window.localStorage.getItem(STORAGE_KEY)
    const parsed = JSON.parse(payload || '[]')
    if (!Array.isArray(parsed)) {
      return []
    }
    return parsed
      .filter(function (entry) {
        return entry && typeof entry === 'object'
      })
      .map(function (entry) {
        return {
          id: Number(entry.id) || Date.now(),
          text: typeof entry.text === 'string' ? entry.text : '',
          completed: Boolean(entry.completed)
        }
      })
      .filter(function (entry) {
        return entry.text.trim().length > 0
      })
  } catch (error) {
    console.error('[todo] 读取本地数据失败:', error)
    saveMessage.value = '读取失败，已使用空列表'
    return []
  }
}

function persistTasks() {
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(tasks.value))
    saveMessage.value = '已自动保存'
  } catch (error) {
    console.error('[todo] 保存到本地失败:', error)
    saveMessage.value = '保存失败'
  }
}

function sanitizeHtml(text) {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

function addTask() {
  if (newTask.value.trim()) {
    tasks.value.unshift({
      id: Date.now(),
      text: sanitizeHtml(newTask.value.trim()),
      completed: false
    })
    newTask.value = ''
    persistTasks()
  }
}

function toggleComplete(taskId) {
  const task = tasks.value.find(function (t) { return t.id === taskId })
  if (task) {
    task.completed = !task.completed
    persistTasks()
  }
}

function deleteTask(taskId) {
  const index = tasks.value.findIndex(function (t) { return t.id === taskId })
  if (index !== -1) {
    tasks.value.splice(index, 1)
    persistTasks()
  }
}
</script>

<template>
  <div class="todo-container">
    <div class="todo-header">
      <h2 class="todo-title">待办事项</h2>
      <span class="task-count">{{ pendingCount }} 项待完成</span>
    </div>

    <div class="add-task">
      <input
        v-model="newTask"
        type="text"
        placeholder="输入新任务..."
        class="task-input"
        @keyup.enter="addTask"
      />
      <button @click="addTask" class="add-btn">+</button>
    </div>
    <div class="save-status">{{ saveMessage }}</div>

    <div class="task-list">
      <div
        v-for="task in tasks"
        :key="task.id"
        class="task-item"
        :class="{ completed: task.completed }"
      >
        <div class="task-content">
          <input
            type="checkbox"
            :checked="task.completed"
            @change="toggleComplete(task.id)"
            class="task-checkbox"
          />
          <span class="task-text">{{ task.text }}</span>
        </div>
        <button @click="deleteTask(task.id)" class="delete-btn">x</button>
      </div>

      <div v-if="tasks.length === 0" class="empty-state">
        <p>暂无待办事项，添加一个新任务吧！</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.todo-container {
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 18px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-sizing: border-box;
}

.todo-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 14px;
  padding-bottom: 10px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.todo-title {
  color: white;
  font-size: 1.25rem;
  font-weight: 600;
  margin: 0;
  text-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
}

.task-count {
  color: rgba(255, 255, 255, 0.7);
  font-size: 0.9rem;
  font-weight: 400;
  background: rgba(255, 255, 255, 0.1);
  padding: 4px 12px;
  border-radius: 12px;
}

.add-task {
  display: flex;
  gap: 8px;
  margin-bottom: 8px;
}

.task-input {
  flex: 1;
  padding: 8px 12px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 10px;
  background: rgba(255, 255, 255, 0.9);
  color: #333;
  font-size: 0.9rem;
  outline: none;
  transition: all 0.3s ease;
}

.task-input:focus {
  border-color: rgba(102, 126, 234, 0.8);
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.add-btn {
  padding: 8px 14px;
  border: none;
  border-radius: 10px;
  background: white;
  color: black;
  font-size: 1rem;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
  justify-content: center;
}

.add-btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
}

.save-status {
  margin-bottom: 10px;
  text-align: left;
  color: rgba(255, 255, 255, 0.65);
  font-size: 0.8rem;
}

.task-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  max-height: 28vh;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 4px;
  box-sizing: border-box;
}

.task-list::-webkit-scrollbar {
  width: 6px;
}

.task-list::-webkit-scrollbar-track {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 3px;
}

.task-list::-webkit-scrollbar-thumb {
  background: rgba(255, 255, 255, 0.2);
  border-radius: 3px;
  transition: background 0.3s ease;
}

.task-list::-webkit-scrollbar-thumb:hover {
  background: rgba(255, 255, 255, 0.3);
}

.task-list {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.2) rgba(255, 255, 255, 0.05);
}

.task-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 12px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 10px;
  transition: all 0.3s ease;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.task-item:hover {
  background: rgba(255, 255, 255, 0.15);
  transform: translateX(4px);
}

.task-item.completed {
  opacity: 0.6;
}

.task-content {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
}

.task-checkbox {
  width: 16px;
  height: 16px;
  cursor: pointer;
  accent-color: #667eea;
}

.task-text {
  color: white;
  font-size: 0.9rem;
  flex: 1;
  word-break: break-all;
}

.task-item.completed .task-text {
  text-decoration: line-through;
  color: rgba(255, 255, 255, 0.5);
}

.delete-btn {
  padding: 4px 8px;
  border: none;
  border-radius: 6px;
  background: rgba(255, 107, 107, 0.2);
  color: rgba(255, 107, 107, 0.8);
  font-size: 0.85rem;
  cursor: pointer;
  transition: all 0.3s ease;
  opacity: 0;
}

.task-item:hover .delete-btn {
  opacity: 1;
}

.delete-btn:hover {
  background: rgba(255, 107, 107, 0.3);
  color: #ff6b6b;
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

@media (max-width: 768px) {
  .todo-container {
    padding: 14px;
  }

  .todo-title {
    font-size: 1.15rem;
  }

  .task-input {
    padding: 8px 12px;
    font-size: 0.85rem;
  }

  .add-btn {
    padding: 8px 12px;
    font-size: 0.9rem;
  }
}
</style>

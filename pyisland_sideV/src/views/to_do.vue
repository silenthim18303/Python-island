<script setup>
import { ref, reactive } from 'vue'

// 待办事项数据
const newTask = ref('')
const tasks = reactive([
  { id: 1, text: '待办事项可为你记录和管理任务组织和效率。组织和效率。', completed: false },
  { id: 2, text: '待办事项支持离线语音录入，无需网络连接。', completed: false },
  { id: 3, text: '你可以直接将照片放置在待办事项中，方便查看。', completed: false }
])

// HTML转义工具函数
const sanitizeHtml = (text) => {
  if (!text) return ''
  return text
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;')
}

// 添加新任务 - 包含XSS防护
const addTask = () => {
  if (newTask.value.trim()) {
    tasks.push({
      id: Date.now(),
      text: sanitizeHtml(newTask.value.trim()),
      completed: false
    })
    newTask.value = ''
  }
}

// 切换完成状态
const toggleComplete = (taskId) => {
  const task = tasks.find(t => t.id === taskId)
  if (task) {
    task.completed = !task.completed
  }
}

// 删除任务
const deleteTask = (taskId) => {
  const index = tasks.findIndex(t => t.id === taskId)
  if (index !== -1) {
    tasks.splice(index, 1)
  }
}
</script>

<template>
  <div class="todo-container">
    <div class="todo-header">
      <h2 class="todo-title">待办事项</h2>
      <span class="task-count">{{ tasks.filter(t => !t.completed).length }} 项待完成</span>
    </div>
    
    <div class="add-task">
      <input 
        v-model="newTask"
        type="text" 
        placeholder="添加新任务..."
        class="task-input"
        @keyup.enter="addTask"
      />
      <button @click="addTask" class="add-btn">➕</button>
    </div>
    
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
        <button @click="deleteTask(task.id)" class="delete-btn">🗑️</button>
      </div>
      
      <div v-if="tasks.length === 0" class="empty-state">
        <p>🎉 暂无待办事项，添加一个新任务吧！</p>
      </div>
    </div>
  </div>
</template>

<style scoped>
.todo-container {
  background: rgb(0 0 0 / 0.8);
  backdrop-filter: blur(12px);
  border-radius: 20px;
  padding: 24px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  box-sizing: border-box;
}

.todo-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding-bottom: 12px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.todo-title {
  color: white;
  font-size: 1.5rem;
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
  gap: 10px;
  margin-bottom: 20px;
}

.task-input {
  flex: 1;
  padding: 12px 16px;
  border: 1px solid rgba(255, 255, 255, 0.2);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.9);
  color: #333;
  font-size: 1rem;
  outline: none;
  transition: all 0.3s ease;
}

.task-input:focus {
  border-color: rgba(102, 126, 234, 0.8);
  box-shadow: 0 0 0 3px rgba(102, 126, 234, 0.1);
}

.add-btn {
  padding: 12px 20px;
  border: none;
  border-radius: 12px;
  background: white;
  color: black;
  font-size: 1.2rem;
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

.task-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-height: 50vh;
  overflow-y: auto;
  overflow-x: hidden;
  padding-right: 4px;
  box-sizing: border-box;
}

/* 自定义滚动条 - 与整体设计风格一致 */
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

/* Firefox 滚动条 */
.task-list {
  scrollbar-width: thin;
  scrollbar-color: rgba(255, 255, 255, 0.2) rgba(255, 255, 255, 0.05);
}

.task-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 14px 16px;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
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
  gap: 12px;
  flex: 1;
}

.task-checkbox {
  width: 18px;
  height: 18px;
  cursor: pointer;
  accent-color: #667eea;
}

.task-text {
  color: white;
  font-size: 1rem;
  flex: 1;
  word-break: break-all;
}

.task-item.completed .task-text {
  text-decoration: line-through;
  color: rgba(255, 255, 255, 0.5);
}

.delete-btn {
  padding: 6px 10px;
  border: none;
  border-radius: 8px;
  background: rgba(255, 107, 107, 0.2);
  color: rgba(255, 107, 107, 0.8);
  font-size: 1.1rem;
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
  padding: 40px 20px;
  color: rgba(255, 255, 255, 0.6);
  font-size: 1rem;
}

.empty-state p {
  margin: 0;
}

/* 响应式设计 */
@media (max-width: 768px) {
  .todo-container {
    padding: 16px;
  }
  
  .todo-title {
    font-size: 1.3rem;
  }
  
  .task-input {
    padding: 10px 14px;
    font-size: 0.9rem;
  }
  
  .add-btn {
    padding: 10px 16px;
    font-size: 1rem;
  }
}
</style>
<script setup>
import TodoPanel from '../features/todo/TodoPanel.vue'
import FileTransfer from '../features/transfer/FileTransfer.vue'
import BluetoothList from '../features/bluetooth/BluetoothList.vue'
</script>

<template>
  <div class="transfer-view">
    <div class="module-wrapper">
      <TodoPanel />
    </div>
    <div class="module-wrapper">
      <FileTransfer />
    </div>
    <div class="module-wrapper">
      <BluetoothList />
    </div>
  </div>
</template>

<style scoped>
.transfer-view {
  width: 100%;
  min-height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 8px 8px;
  box-sizing: border-box;
}

.module-wrapper {
  width: 100%;
  max-width: 600px;
  margin-bottom: 14px;
  box-sizing: border-box;
}

@media (max-width: 768px) {
  .transfer-view {
    padding: 8px 8px;
  }

  .module-wrapper {
    margin-bottom: 12px;
  }
}
</style>

<script setup lang="ts">
import { ref, watch } from 'vue'
import BaseModal from './BaseModal.vue'

const props = defineProps<{
  visible: boolean
  title?: string
  initialValue: string
  placeholder?: string
  loading?: boolean
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm', value: string): void
}>()

const inputValue = ref(props.initialValue)

watch(() => props.visible, (newVal) => {
  if (newVal) {
    inputValue.value = props.initialValue
  }
})

const handleConfirm = () => {
  if (inputValue.value.trim()) {
    emit('confirm', inputValue.value.trim())
  }
}
</script>

<template>
  <BaseModal 
    :visible="visible" 
    :title="title || '重命名'" 
    width="440px"
    @close="$emit('close')"
  >
    <div class="rename-content">
      <div class="form-item">
        <label class="form-label">新名称</label>
        <input 
          v-model="inputValue" 
          type="text" 
          class="form-input" 
          :placeholder="placeholder || '请输入名称'"
          autofocus
          @keyup.enter="handleConfirm"
          :disabled="loading"
        >
      </div>
    </div>
    
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('close')" :disabled="loading">取消</button>
      <button class="btn btn-primary" @click="handleConfirm" :disabled="loading || !inputValue.trim()">
        <span v-if="loading" class="loading-spinner"></span>
        {{ loading ? '保存中...' : '确认保存' }}
      </button>
    </template>
  </BaseModal>
</template>

<style scoped>
.form-item {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-label {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
}

.form-input {
  width: 100%;
  padding: 10px 12px;
  border-radius: var(--radius-md);
  border: 1px solid var(--border-light);
  background: var(--bg-secondary);
  color: var(--text-primary);
  font-size: 14px;
  transition: all 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: var(--primary);
  background: var(--bg-surface);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.btn {
  padding: 8px 16px;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.btn-secondary {
  background: var(--bg-surface);
  border-color: var(--border-light);
  color: var(--text-secondary);
}

.btn-secondary:hover {
  background: var(--bg-secondary);
  border-color: var(--gray-300);
}

.btn-primary {
  background: var(--primary);
  color: white;
}

.btn-primary:hover {
  background: var(--primary-hover);
  box-shadow: 0 2px 4px rgba(59, 130, 246, 0.2);
}

.btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.loading-spinner {
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  display: inline-block;
  margin-right: 8px;
  vertical-align: middle;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}
</style>

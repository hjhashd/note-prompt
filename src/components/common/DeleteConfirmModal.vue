<script setup lang="ts">
import { ref, watch } from 'vue'
import BaseModal from './BaseModal.vue'
import { AlertTriangle, CheckCircle2 } from 'lucide-vue-next'

const props = defineProps<{
  visible: boolean
  title?: string
  message?: string
  loading?: boolean
  showCheckbox?: boolean
  checkboxLabel?: string
}>()

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'confirm', checkboxChecked: boolean): void
}>()

const isChecked = ref(false)

watch(() => props.visible, (newVal) => {
  if (newVal) {
    isChecked.value = false
  }
})
</script>

<template>
  <BaseModal 
    :visible="visible" 
    :title="title || '确认删除'" 
    width="400px"
    @close="$emit('close')"
  >
    <div class="delete-content">
      <div class="alert-icon">
        <AlertTriangle :size="32" />
      </div>
      <div class="message-group">
        <p class="main-message">{{ message || '确定要删除吗？' }}</p>
        <p class="sub-message">此操作不可撤销，相关数据将无法找回。</p>
        
        <div v-if="showCheckbox" class="checkbox-option" @click="isChecked = !isChecked">
          <div class="checkbox" :class="{ checked: isChecked }">
            <CheckCircle2 v-if="isChecked" :size="14" />
          </div>
          <span>{{ checkboxLabel || '同时删除关联项' }}</span>
        </div>
      </div>
    </div>
    
    <template #footer>
      <button class="btn btn-secondary" @click="$emit('close')" :disabled="loading">取消</button>
      <button class="btn btn-danger" @click="$emit('confirm', isChecked)" :disabled="loading">
        <span v-if="loading" class="loading-spinner"></span>
        {{ loading ? '删除中...' : '确认删除' }}
      </button>
    </template>
  </BaseModal>
</template>

<style scoped>
.delete-content {
  display: flex;
  gap: 16px;
  align-items: flex-start;
}

.alert-icon {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  background: #fee2e2;
  color: var(--danger);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.message-group {
  flex: 1;
}

.main-message {
  font-size: 16px;
  font-weight: 500;
  color: var(--text-primary);
  margin: 0 0 8px 0;
}

.sub-message {
  font-size: 14px;
  color: var(--text-secondary);
  margin: 0;
  line-height: 1.5;
}

.checkbox-option {
  margin-top: 16px;
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
  user-select: none;
  font-size: 14px;
  color: var(--text-secondary);
  padding: 8px 12px;
  background: var(--bg-secondary);
  border-radius: var(--radius-sm);
  transition: all 0.2s;
}

.checkbox-option:hover {
  background: var(--gray-100);
  color: var(--text-primary);
}

.checkbox {
  width: 18px;
  height: 18px;
  border: 2px solid var(--border-light);
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
  background: white;
}

.checkbox.checked {
  background: var(--primary);
  border-color: var(--primary);
  color: white;
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

.btn-danger {
  background: var(--danger);
  color: white;
}

.btn-danger:hover {
  background: #dc2626;
  box-shadow: 0 2px 4px rgba(239, 68, 68, 0.2);
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

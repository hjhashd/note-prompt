<script setup lang="ts">
import { ref, watch } from 'vue'
import { X } from 'lucide-vue-next'
import { resetPassword } from '@/api/admin'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  visible: boolean
  userId: number | null
  username: string
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'success'): void
}>()

const { toast } = useToast()

const loading = ref(false)
const formData = ref({
  newPassword: '',
  confirmPassword: ''
})

const errors = ref<Record<string, string>>({})

const resetForm = () => {
  formData.value = {
    newPassword: '',
    confirmPassword: ''
  }
  errors.value = {}
}

const validateForm = () => {
  errors.value = {}
  
  if (!formData.value.newPassword) {
    errors.value.newPassword = '请输入新密码'
  } else if (formData.value.newPassword.length < 6 || formData.value.newPassword.length > 20) {
    errors.value.newPassword = '密码长度为6-20位'
  } else if (!/(?=.*[a-zA-Z])(?=.*\d)/.test(formData.value.newPassword)) {
    errors.value.newPassword = '密码需包含字母和数字'
  }
  
  if (!formData.value.confirmPassword) {
    errors.value.confirmPassword = '请确认密码'
  } else if (formData.value.confirmPassword !== formData.value.newPassword) {
    errors.value.confirmPassword = '两次输入的密码不一致'
  }
  
  return Object.keys(errors.value).length === 0
}

const handleSubmit = async () => {
  if (!validateForm() || !props.userId) return
  
  loading.value = true
  try {
    await resetPassword(props.userId, formData.value.newPassword)
    toast('密码重置成功', 'success')
    emit('success')
    handleClose()
  } catch (error: any) {
    console.error('Failed to reset password:', error)
    const message = error?.response?.data?.detail || '密码重置失败'
    toast(message, 'error')
  } finally {
    loading.value = false
  }
}

const handleClose = () => {
  emit('update:visible', false)
  resetForm()
}

watch(() => props.visible, (val) => {
  if (!val) {
    resetForm()
  }
})
</script>

<template>
  <div v-if="visible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-content">
      <div class="modal-header">
        <h3>重置密码</h3>
        <button class="modal-close" @click="handleClose">
          <X :size="18" />
        </button>
      </div>
      
      <div class="modal-body">
        <div class="user-info">
          <span class="label">用户：</span>
          <span class="username">{{ username }}</span>
        </div>
        
        <form @submit.prevent="handleSubmit" class="form">
          <div class="form-group">
            <label class="form-label">
              新密码 <span class="required">*</span>
            </label>
            <input
              v-model="formData.newPassword"
              type="password"
              class="form-input"
              :class="{ 'error': errors.newPassword }"
              placeholder="6-20位，需包含字母和数字"
            />
            <span v-if="errors.newPassword" class="error-text">{{ errors.newPassword }}</span>
          </div>
          
          <div class="form-group">
            <label class="form-label">
              确认密码 <span class="required">*</span>
            </label>
            <input
              v-model="formData.confirmPassword"
              type="password"
              class="form-input"
              :class="{ 'error': errors.confirmPassword }"
              placeholder="请再次输入密码"
            />
            <span v-if="errors.confirmPassword" class="error-text">{{ errors.confirmPassword }}</span>
          </div>
          
          <div class="form-actions">
            <button type="button" class="btn btn-secondary" @click="handleClose">
              取消
            </button>
            <button type="submit" class="btn btn-primary" :disabled="loading">
              {{ loading ? '提交中...' : '确定' }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </div>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  width: 90%;
  max-width: 400px;
  overflow: hidden;
  box-shadow: var(--shadow-lg);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border-subtle);
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--gray-900);
}

.modal-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  color: var(--gray-500);
  cursor: pointer;
  border-radius: var(--radius-sm);
}

.modal-close:hover {
  background: var(--bg-primary);
  color: var(--gray-700);
}

.modal-body {
  padding: 24px;
}

.user-info {
  margin-bottom: 20px;
  padding: 12px;
  background: var(--bg-primary);
  border-radius: var(--radius-md);
}

.user-info .label {
  color: var(--gray-500);
  font-size: 14px;
}

.user-info .username {
  color: var(--gray-900);
  font-weight: 500;
}

.form {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-label {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-700);
}

.required {
  color: var(--danger);
}

.form-input {
  padding: 10px 12px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  font-size: 14px;
  color: var(--gray-900);
  background: var(--bg-primary);
  transition: all var(--transition-fast);
}

.form-input:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-light);
}

.form-input.error {
  border-color: var(--danger);
}

.error-text {
  font-size: 12px;
  color: var(--danger);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 8px;
}

.btn {
  padding: 10px 20px;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn-primary {
  background: var(--primary);
  color: white;
  border: none;
}

.btn-primary:hover:not(:disabled) {
  background: var(--primary-600);
}

.btn-primary:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.btn-secondary {
  background: var(--bg-primary);
  color: var(--gray-700);
  border: 1px solid var(--border-subtle);
}

.btn-secondary:hover {
  background: var(--gray-100);
}
</style>

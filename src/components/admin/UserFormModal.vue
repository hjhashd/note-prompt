<script setup lang="ts">
import { ref, watch, computed, onMounted } from 'vue'
import { X } from 'lucide-vue-next'
import {
  createUser,
  updateUser,
  getDepartments,
  getRoles,
  getUserById,
  type DepartmentInfo,
  type RoleInfo,
  type UserInfo
} from '@/api/admin'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  visible: boolean
  userId?: number | null
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'success', payload?: any): void
}>()

const { toast } = useToast()

const isEdit = computed(() => !!props.userId)
const modalTitle = computed(() => isEdit.value ? '编辑用户' : '新增用户')

const loading = ref(false)
const departments = ref<DepartmentInfo[]>([])
const roles = ref<RoleInfo[]>([])

const formData = ref({
  username: '',
  realName: '',
  password: '',
  departmentId: undefined as number | undefined,
  status: 1,
  roleIds: [] as number[]
})

const selectedRoleId = computed<number | null>({
  get: () => formData.value.roleIds[0] ?? null,
  set: (value) => {
    formData.value.roleIds = value ? [value] : []
  }
})

const errors = ref<Record<string, string>>({})

const resetForm = () => {
  formData.value = {
    username: '',
    realName: '',
    password: '',
    departmentId: undefined,
    status: 1,
    roleIds: []
  }
  errors.value = {}
}

const validateForm = () => {
  errors.value = {}

  const username = formData.value.username.trim()
  const password = formData.value.password
  const isPhoneUsername = /^1\d{10}$/.test(username)

  if (!username) {
    errors.value.username = '请输入用户名'
  } else if (!isPhoneUsername) {
    if (username.length < 4 || username.length > 20) {
      errors.value.username = '用户名长度为4-20位'
    } else if (!/^[a-zA-Z][a-zA-Z0-9_]*$/.test(username)) {
      errors.value.username = '用户名必须以字母开头，只能包含字母、数字和下划线'
    }
  }
  
  if (!formData.value.realName) {
    errors.value.realName = '请输入真实姓名'
  } else if (formData.value.realName.length < 2 || formData.value.realName.length > 20) {
    errors.value.realName = '真实姓名长度为2-20位'
  }
  
  if (!isEdit.value) {
    if (!password) {
      errors.value.password = '请输入密码'
    } else if (isPhoneUsername) {
      const lastSix = username.slice(-6)
      if (password !== lastSix) {
        errors.value.password = '手机号用户密码需为手机号后六位'
      }
    } else if (password.length < 6 || password.length > 20) {
      errors.value.password = '密码长度为6-20位'
    } else if (!/(?=.*[a-zA-Z])(?=.*\d)/.test(password)) {
      errors.value.password = '密码需包含字母和数字'
    }
  }
  
  return Object.keys(errors.value).length === 0
}

const fetchOptions = async () => {
  try {
    const [deptData, roleData] = await Promise.all([
      getDepartments(),
      getRoles()
    ])
    departments.value = deptData
    roles.value = roleData
  } catch (error) {
    console.error('Failed to fetch options:', error)
  }
}

const fetchUserData = async () => {
  if (!props.userId) return
  
  loading.value = true
  try {
    const user = await getUserById(props.userId)
    const primaryRoleId = user.roles[0]?.id
    formData.value = {
      username: user.username,
      realName: user.realName,
      password: '',
      departmentId: user.departmentId,
      status: user.status,
      roleIds: primaryRoleId ? [primaryRoleId] : []
    }
  } catch (error) {
    console.error('Failed to fetch user:', error)
    toast('获取用户信息失败', 'error')
  } finally {
    loading.value = false
  }
}

const handleSubmit = async () => {
  if (!validateForm()) return
  
  loading.value = true
  try {
    if (isEdit.value && props.userId) {
      await updateUser(props.userId, {
        realName: formData.value.realName,
        departmentId: formData.value.departmentId,
        status: formData.value.status,
        roleIds: formData.value.roleIds
      })
      toast('用户更新成功', 'success')
      emit('success', { type: 'edit', id: props.userId, data: formData.value })
    } else {
      await createUser({
        username: formData.value.username,
        realName: formData.value.realName,
        password: formData.value.password,
        departmentId: formData.value.departmentId,
        status: formData.value.status,
        roleIds: formData.value.roleIds
      })
      toast('用户创建成功', 'success')
      emit('success', { type: 'create' })
    }
    
    handleClose()
  } catch (error: any) {
    console.error('Failed to save user:', error)
    const message = error?.response?.data?.detail || '操作失败'
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
  if (val) {
    fetchOptions()
    if (props.userId) {
      fetchUserData()
    }
  }
})
</script>

<template>
  <div v-if="visible" class="modal-overlay" @click.self="handleClose">
    <div class="modal-content">
      <div class="modal-header">
        <h3>{{ modalTitle }}</h3>
        <button class="modal-close" @click="handleClose">
          <X :size="18" />
        </button>
      </div>
      
      <div class="modal-body">
        <div v-if="loading && isEdit" class="loading-state">
          加载中...
        </div>
        
        <form v-else @submit.prevent="handleSubmit" class="form">
          <div class="form-group">
            <label class="form-label">
              用户名 <span class="required">*</span>
            </label>
            <input
              v-model="formData.username"
              type="text"
              class="form-input"
              :class="{ 'error': errors.username }"
              :disabled="isEdit"
              placeholder="4-20位字母开头或手机号"
            />
            <span v-if="errors.username" class="error-text">{{ errors.username }}</span>
          </div>
          
          <div class="form-group">
            <label class="form-label">
              真实姓名 <span class="required">*</span>
            </label>
            <input
              v-model="formData.realName"
              type="text"
              class="form-input"
              :class="{ 'error': errors.realName }"
              placeholder="2-20位"
            />
            <span v-if="errors.realName" class="error-text">{{ errors.realName }}</span>
          </div>
          
          <div v-if="!isEdit" class="form-group">
            <label class="form-label">
              密码 <span class="required">*</span>
            </label>
            <input
              v-model="formData.password"
              type="password"
              class="form-input"
              :class="{ 'error': errors.password }"
              placeholder="6-20位或手机号后六位"
            />
            <span v-if="errors.password" class="error-text">{{ errors.password }}</span>
          </div>
          
          <div class="form-group">
            <label class="form-label">部门</label>
            <select v-model="formData.departmentId" class="form-select">
              <option :value="undefined">请选择部门</option>
              <option v-for="dept in departments" :key="dept.id" :value="dept.id">
                {{ dept.deptName }}
              </option>
            </select>
          </div>
          
          <div class="form-group">
            <label class="form-label">状态</label>
            <select v-model="formData.status" class="form-select">
              <option :value="1">正常</option>
              <option :value="0">禁用</option>
            </select>
          </div>
          
          <div class="form-group">
            <label class="form-label">角色</label>
            <div class="checkbox-group">
              <label v-for="role in roles" :key="role.id" class="checkbox-item">
                <input
                  type="radio"
                  :value="role.id"
                  v-model="selectedRoleId"
                  name="user-role"
                />
                <span>{{ role.roleName }}</span>
              </label>
            </div>
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
  max-width: 480px;
  max-height: 80vh;
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
  overflow-y: auto;
}

.loading-state {
  text-align: center;
  padding: 40px;
  color: var(--gray-500);
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

.form-input,
.form-select {
  padding: 10px 12px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  font-size: 14px;
  color: var(--gray-900);
  background: var(--bg-primary);
  transition: all var(--transition-fast);
}

.form-input:focus,
.form-select:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-light);
}

.form-input.error {
  border-color: var(--danger);
}

.form-input:disabled {
  background: var(--gray-100);
  cursor: not-allowed;
}

.error-text {
  font-size: 12px;
  color: var(--danger);
}

.checkbox-group {
  display: flex;
  flex-wrap: wrap;
  gap: 12px;
}

.checkbox-item {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  font-size: 14px;
  color: var(--gray-700);
}

.checkbox-item input[type="checkbox"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
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

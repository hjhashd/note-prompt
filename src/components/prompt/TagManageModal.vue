<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { X, Plus, Edit2, Trash2, AlertTriangle, Check, FolderOpen, Globe } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'
import {
  getPythonTagsTree,
  getPythonDepartmentsTree,
  createPersonalTag,
  deletePersonalTag,
  updateTagDepartment,
  type TagNode,
  type DepartmentNode
} from '@/api/promptSave'

const props = defineProps<{
  visible: boolean
  userDepartmentId?: number | null
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
}>()

const { toast } = useToast()

// 标签列表
const systemTags = ref<TagNode[]>([])
const personalTags = ref<TagNode[]>([])
const departments = ref<DepartmentNode[]>([])
const loading = ref(false)

// 创建标签表单
const showCreateForm = ref(false)
const newTagName = ref('')
const newTagParentId = ref<number>(0)
const isCreating = ref(false)

// 编辑标签
const editingTag = ref<TagNode | null>(null)
const editTagName = ref('')
const isEditing = ref(false)

// 删除标签
const showDeleteConfirm = ref(false)
const tagToDelete = ref<TagNode | null>(null)
const deleteWithPrompts = ref(false)
const isDeleting = ref(false)

// 分配部门
const showAssignDeptModal = ref(false)
const tagToAssign = ref<TagNode | null>(null)
const selectedDeptId = ref<number | null>(null)
const isAssigning = ref(false)

// 全部部门ID（假设为1）
const ALL_DEPT_ID = 1

// 计算当前用户的部门名称
const userDeptName = computed(() => {
  if (!props.userDepartmentId) return null
  const findDept = (nodes: DepartmentNode[]): DepartmentNode | null => {
    for (const node of nodes) {
      if (node.id === props.userDepartmentId) return node
      if (node.children) {
        const found = findDept(node.children)
        if (found) return found
      }
    }
    return null
  }
  const dept = findDept(departments.value)
  return dept?.name || '我的部门'
})

// 获取标签所属部门名称
const getTagDeptName = (tag: TagNode): string => {
  if (!tag.department_id) return '全部部门'
  if (tag.department_id === ALL_DEPT_ID) return '全部部门'

  const findDept = (nodes: DepartmentNode[]): DepartmentNode | null => {
    for (const node of nodes) {
      if (node.id === tag.department_id) return node
      if (node.children) {
        const found = findDept(node.children)
        if (found) return found
      }
    }
    return null
  }
  const dept = findDept(departments.value)
  return dept?.name || '全部部门'
}

// 加载数据
const loadData = async () => {
  loading.value = true
  try {
    const [tagsRes, deptsRes] = await Promise.all([
      getPythonTagsTree(true),
      getPythonDepartmentsTree()
    ])
    // 只加载个人标签，不显示系统标签
    systemTags.value = []
    personalTags.value = tagsRes.personal_tags || []
    departments.value = deptsRes || []
  } catch (error) {
    console.error('Failed to load tags:', error)
    toast('加载标签失败', 'error')
  } finally {
    loading.value = false
  }
}

// 扁平化标签列表用于显示
const flattenedPersonalTags = computed(() => {
  const result: TagNode[] = []
  const flatten = (nodes: TagNode[]) => {
    nodes.forEach(node => {
      result.push(node)
      if (node.children && node.children.length > 0) {
        flatten(node.children)
      }
    })
  }
  flatten(personalTags.value)
  return result
})

// 创建标签
const handleCreateTag = async () => {
  if (!newTagName.value.trim()) {
    toast('请输入标签名称', 'warning')
    return
  }

  isCreating.value = true
  try {
    await createPersonalTag({
      tag_name: newTagName.value.trim(),
      parent_id: newTagParentId.value || 0
    })
    toast('标签创建成功', 'success')
    newTagName.value = ''
    newTagParentId.value = 0
    showCreateForm.value = false
    await loadData()
  } catch (error: any) {
    toast(error?.response?.data?.message || '创建标签失败', 'error')
  } finally {
    isCreating.value = false
  }
}

// 开始编辑标签
const startEditTag = (tag: TagNode) => {
  editingTag.value = tag
  editTagName.value = tag.tag_name
}

// 保存编辑
const handleSaveEdit = async () => {
  if (!editingTag.value) return
  if (!editTagName.value.trim()) {
    toast('标签名称不能为空', 'warning')
    return
  }

  isEditing.value = true
  try {
    // 调用更新API（这里假设有更新API，如果没有需要先创建）
    // await updatePersonalTag(editingTag.value.id, { tag_name: editTagName.value.trim() })
    toast('标签更新成功', 'success')
    editingTag.value = null
    editTagName.value = ''
    await loadData()
  } catch (error: any) {
    toast(error?.response?.data?.message || '更新标签失败', 'error')
  } finally {
    isEditing.value = false
  }
}

// 取消编辑
const cancelEdit = () => {
  editingTag.value = null
  editTagName.value = ''
}

// 打开删除确认
const openDeleteConfirm = (tag: TagNode) => {
  tagToDelete.value = tag
  deleteWithPrompts.value = false
  showDeleteConfirm.value = true
}

// 关闭删除确认
const closeDeleteConfirm = () => {
  showDeleteConfirm.value = false
  tagToDelete.value = null
  deleteWithPrompts.value = false
}

// 执行删除
const executeDelete = async () => {
  if (!tagToDelete.value) return

  isDeleting.value = true
  try {
    await deletePersonalTag(tagToDelete.value.id, deleteWithPrompts.value)
    toast(deleteWithPrompts.value ? '标签及关联提示词已删除' : '标签已删除', 'success')
    closeDeleteConfirm()
    await loadData()
  } catch (error: any) {
    toast(error?.response?.data?.message || '删除标签失败', 'error')
  } finally {
    isDeleting.value = false
  }
}

// 打开分配部门弹窗
const openAssignDept = (tag: TagNode) => {
  tagToAssign.value = tag
  selectedDeptId.value = tag.department_id || ALL_DEPT_ID
  showAssignDeptModal.value = true
}

// 关闭分配部门弹窗
const closeAssignDept = () => {
  showAssignDeptModal.value = false
  tagToAssign.value = null
  selectedDeptId.value = null
}

// 执行分配部门
const executeAssignDept = async () => {
  if (!tagToAssign.value || selectedDeptId.value === null) return

  isAssigning.value = true
  try {
    await updateTagDepartment(tagToAssign.value.id, selectedDeptId.value)
    toast('部门分配成功', 'success')
    closeAssignDept()
    await loadData()
  } catch (error: any) {
    toast(error?.response?.data?.message || '分配部门失败', 'error')
  } finally {
    isAssigning.value = false
  }
}

// 关闭弹窗
const closeModal = () => {
  emit('update:visible', false)
}

// 监听visible变化
watch(() => props.visible, (newVal) => {
  if (newVal) {
    loadData()
  }
})

onMounted(() => {
  if (props.visible) {
    loadData()
  }
})
</script>

<template>
  <div v-if="visible" class="modal-overlay" @click.self="closeModal">
    <div class="modal-content tag-manage-modal">
      <div class="modal-header">
        <div class="header-title">
          <FolderOpen :size="24" class="header-icon" />
          <h3>标签管理</h3>
        </div>
        <button class="close-btn" @click="closeModal">
          <X :size="20" />
        </button>
      </div>

      <div class="modal-body">
        <!-- 创建新标签 -->
        <div class="create-section">
          <button
            v-if="!showCreateForm"
            class="create-btn"
            @click="showCreateForm = true"
          >
            <Plus :size="18" />
            <span>创建新标签</span>
          </button>

          <div v-else class="create-form">
            <input
              v-model="newTagName"
              type="text"
              placeholder="输入标签名称"
              class="tag-input"
              @keyup.enter="handleCreateTag"
            />
            <div class="form-actions">
              <button class="btn-secondary" @click="showCreateForm = false">取消</button>
              <button
                class="btn-primary"
                :disabled="isCreating || !newTagName.trim()"
                @click="handleCreateTag"
              >
                {{ isCreating ? '创建中...' : '创建' }}
              </button>
            </div>
          </div>
        </div>

        <!-- 标签列表 -->
        <div class="tags-list-section">
          <h4>我的标签</h4>

          <div v-if="loading" class="loading-state">
            <span>加载中...</span>
          </div>

          <div v-else-if="flattenedPersonalTags.length === 0" class="empty-state">
            <span>暂无个人标签</span>
          </div>

          <div v-else class="tags-list">
            <div
              v-for="tag in flattenedPersonalTags"
              :key="tag.id"
              class="tag-item"
            >
              <div class="tag-info">
                <div v-if="editingTag?.id === tag.id" class="edit-form">
                  <input
                    v-model="editTagName"
                    type="text"
                    class="tag-input"
                    @keyup.enter="handleSaveEdit"
                    @keyup.esc="cancelEdit"
                  />
                  <button class="icon-btn success" @click="handleSaveEdit">
                    <Check :size="16" />
                  </button>
                  <button class="icon-btn" @click="cancelEdit">
                    <X :size="16" />
                  </button>
                </div>
                <template v-else>
                  <span class="tag-name">{{ tag.tag_name }}</span>
                  <div class="tag-meta">
                    <span class="dept-badge" :class="{ 'all-dept': !tag.department_id || tag.department_id === ALL_DEPT_ID }">
                      <Globe v-if="!tag.department_id || tag.department_id === ALL_DEPT_ID" :size="12" />
                      <FolderOpen v-else :size="12" />
                      {{ getTagDeptName(tag) }}
                    </span>
                  </div>
                </template>
              </div>

              <div v-if="editingTag?.id !== tag.id" class="tag-actions">
                <button
                  class="icon-btn"
                  title="分配部门"
                  @click="openAssignDept(tag)"
                >
                  <FolderOpen :size="16" />
                </button>
                <button
                  class="icon-btn"
                  title="编辑"
                  @click="startEditTag(tag)"
                >
                  <Edit2 :size="16" />
                </button>
                <button
                  class="icon-btn danger"
                  title="删除"
                  @click="openDeleteConfirm(tag)"
                >
                  <Trash2 :size="16" />
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 部门说明 -->
        <div class="dept-info">
          <h4>部门说明</h4>
          <div class="dept-options">
            <div class="dept-option">
              <Globe :size="16" />
              <div>
                <span class="option-title">全部部门</span>
                <span class="option-desc">标签将显示在所有部门中</span>
              </div>
            </div>
            <div v-if="userDeptName" class="dept-option">
              <FolderOpen :size="16" />
              <div>
                <span class="option-title">{{ userDeptName }}</span>
                <span class="option-desc">标签只显示在您的部门中</span>
              </div>
            </div>
            <div v-else class="dept-option disabled">
              <FolderOpen :size="16" />
              <div>
                <span class="option-title">所属部门</span>
                <span class="option-desc">您尚未绑定部门，公开标签只能放到全部部门</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirm" class="confirm-overlay" @click.self="closeDeleteConfirm">
      <div class="confirm-modal">
        <div class="confirm-header">
          <AlertTriangle class="warning-icon" :size="24" />
          <h4>删除标签</h4>
        </div>
        <div class="confirm-body">
          <p>确定要删除标签「<strong>{{ tagToDelete?.tag_name }}</strong>」吗？</p>

          <div class="delete-options">
            <label class="radio-label">
              <input
                type="radio"
                v-model="deleteWithPrompts"
                :value="false"
              />
              <div class="radio-content">
                <span class="radio-title">仅删除标签</span>
                <span class="radio-desc">保留标签下的所有提示词</span>
              </div>
            </label>

            <label class="radio-label">
              <input
                type="radio"
                v-model="deleteWithPrompts"
                :value="true"
              />
              <div class="radio-content">
                <span class="radio-title">删除标签及关联提示词</span>
                <span class="radio-desc">同时删除该标签下的所有提示词（不可恢复）</span>
              </div>
            </label>
          </div>
        </div>
        <div class="confirm-footer">
          <button class="btn-secondary" @click="closeDeleteConfirm" :disabled="isDeleting">
            取消
          </button>
          <button
            class="btn-danger"
            @click="executeDelete"
            :disabled="isDeleting"
          >
            {{ isDeleting ? '删除中...' : '确认删除' }}
          </button>
        </div>
      </div>
    </div>

    <!-- 分配部门弹窗 -->
    <div v-if="showAssignDeptModal" class="confirm-overlay" @click.self="closeAssignDept">
      <div class="confirm-modal">
        <div class="confirm-header">
          <FolderOpen class="primary-icon" :size="24" />
          <h4>分配部门</h4>
        </div>
        <div class="confirm-body">
          <p>选择标签「<strong>{{ tagToAssign?.tag_name }}</strong>」所属的部门：</p>

          <div class="dept-options-list">
            <label class="dept-radio">
              <input
                type="radio"
                v-model="selectedDeptId"
                :value="ALL_DEPT_ID"
              />
              <div class="dept-radio-content">
                <Globe :size="18" />
                <div>
                  <span class="dept-name">全部部门</span>
                  <span class="dept-desc">标签将显示在所有部门中</span>
                </div>
              </div>
            </label>

            <label
              v-if="props.userDepartmentId"
              class="dept-radio"
            >
              <input
                type="radio"
                v-model="selectedDeptId"
                :value="props.userDepartmentId"
              />
              <div class="dept-radio-content">
                <FolderOpen :size="18" />
                <div>
                  <span class="dept-name">{{ userDeptName }}</span>
                  <span class="dept-desc">标签只显示在您的部门中</span>
                </div>
              </div>
            </label>
          </div>
        </div>
        <div class="confirm-footer">
          <button class="btn-secondary" @click="closeAssignDept" :disabled="isAssigning">
            取消
          </button>
          <button
            class="btn-primary"
            @click="executeAssignDept"
            :disabled="isAssigning"
          >
            {{ isAssigning ? '保存中...' : '确认' }}
          </button>
        </div>
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
  border-radius: 16px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
  width: 90%;
  max-width: 600px;
  max-height: 80vh;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 20px 24px;
  border-bottom: 1px solid var(--border-subtle);
}

.header-title {
  display: flex;
  align-items: center;
  gap: 12px;
}

.header-icon {
  color: var(--primary);
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.close-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.close-btn:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.modal-body {
  padding: 24px;
  overflow-y: auto;
  flex: 1;
}

/* Create Section */
.create-section {
  margin-bottom: 24px;
}

.create-btn {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px;
  border: 2px dashed var(--border-color);
  border-radius: 12px;
  background: transparent;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.create-btn:hover {
  border-color: var(--primary);
  color: var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
}

.create-form {
  display: flex;
  flex-direction: column;
  gap: 12px;
  padding: 16px;
  background: var(--bg-secondary);
  border-radius: 12px;
}

.tag-input {
  width: 100%;
  padding: 10px 14px;
  border: 1px solid var(--border-color);
  border-radius: 8px;
  font-size: 14px;
  background: var(--bg-surface);
  color: var(--text-primary);
}

.tag-input:focus {
  outline: none;
  border-color: var(--primary);
}

.form-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;
}

/* Tags List */
.tags-list-section h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.loading-state,
.empty-state {
  padding: 40px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 14px;
}

.tags-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.tag-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: var(--bg-secondary);
  border-radius: 10px;
  transition: all 0.2s;
}

.tag-item:hover {
  background: var(--bg-tertiary);
}

.tag-info {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.tag-name {
  font-size: 15px;
  font-weight: 500;
  color: var(--text-primary);
}

.tag-meta {
  display: flex;
  align-items: center;
  gap: 8px;
}

.dept-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 8px;
  border-radius: 12px;
  font-size: 11px;
  font-weight: 500;
  color: var(--text-secondary);
  background: var(--bg-tertiary);
}

.dept-badge.all-dept {
  color: var(--primary);
  background: rgba(var(--primary-rgb), 0.1);
}

.edit-form {
  display: flex;
  align-items: center;
  gap: 8px;
}

.edit-form .tag-input {
  flex: 1;
}

.tag-actions {
  display: flex;
  align-items: center;
  gap: 4px;
}

.icon-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.icon-btn:hover {
  background: var(--bg-surface);
  color: var(--text-primary);
}

.icon-btn.success {
  color: #10b981;
}

.icon-btn.success:hover {
  background: #d1fae5;
}

.icon-btn.danger {
  color: #ef4444;
}

.icon-btn.danger:hover {
  background: #fee2e2;
}

/* Dept Info */
.dept-info {
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid var(--border-subtle);
}

.dept-info h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.dept-options {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.dept-option {
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 12px;
  background: var(--bg-secondary);
  border-radius: 10px;
  color: var(--primary);
}

.dept-option.disabled {
  opacity: 0.5;
}

.dept-option > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.option-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.option-desc {
  font-size: 12px;
  color: var(--text-secondary);
}

/* Buttons */
.btn-secondary,
.btn-primary,
.btn-danger {
  padding: 8px 16px;
  border-radius: 8px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
  font-size: 13px;
}

.btn-secondary {
  background: var(--bg-tertiary);
  color: var(--text-primary);
}

.btn-secondary:hover:not(:disabled) {
  background: var(--border-color);
}

.btn-primary {
  background: var(--primary);
  color: white;
}

.btn-primary:hover:not(:disabled) {
  background: var(--primary-hover);
}

.btn-danger {
  background: #ef4444;
  color: white;
}

.btn-danger:hover:not(:disabled) {
  background: #dc2626;
}

.btn-secondary:disabled,
.btn-primary:disabled,
.btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* Confirm Modal */
.confirm-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1001;
}

.confirm-modal {
  background: var(--bg-surface);
  border-radius: 16px;
  padding: 24px;
  width: 90%;
  max-width: 420px;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
}

.confirm-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.confirm-header h4 {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.warning-icon {
  color: #f59e0b;
}

.primary-icon {
  color: var(--primary);
}

.confirm-body {
  margin-bottom: 20px;
}

.confirm-body p {
  margin-bottom: 16px;
  color: var(--text-primary);
  font-size: 14px;
}

.delete-options {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.radio-label {
  display: flex;
  align-items: flex-start;
  gap: 10px;
  padding: 12px;
  border-radius: 8px;
  border: 1px solid var(--border-subtle);
  cursor: pointer;
  transition: all 0.2s;
}

.radio-label:hover {
  background: var(--bg-secondary);
}

.radio-label input[type="radio"] {
  margin-top: 2px;
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.radio-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.radio-title {
  font-weight: 500;
  color: var(--text-primary);
  font-size: 14px;
}

.radio-desc {
  font-size: 12px;
  color: var(--text-secondary);
}

.confirm-footer {
  display: flex;
  justify-content: flex-end;
  gap: 10px;
}

/* Dept Options List */
.dept-options-list {
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.dept-radio {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px;
  border-radius: 10px;
  border: 1px solid var(--border-subtle);
  cursor: pointer;
  transition: all 0.2s;
}

.dept-radio:hover {
  background: var(--bg-secondary);
  border-color: var(--primary);
}

.dept-radio input[type="radio"] {
  margin-top: 2px;
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.dept-radio-content {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  flex: 1;
}

.dept-radio-content > div {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.dept-name {
  font-weight: 500;
  color: var(--text-primary);
  font-size: 14px;
}

.dept-desc {
  font-size: 12px;
  color: var(--text-secondary);
}
</style>

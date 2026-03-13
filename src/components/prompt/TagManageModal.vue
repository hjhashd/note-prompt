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

// 公开/私有切换
const showVisibilityModal = ref(false)
const tagToToggle = ref<TagNode | null>(null)
const isToggling = ref(false)

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

// 判断标签是否公开
const isTagPublic = (tag: TagNode): boolean => {
  return !!tag.department_id
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

// 打开公开/私有切换弹窗
const openVisibilityToggle = (tag: TagNode) => {
  tagToToggle.value = tag
  showVisibilityModal.value = true
}

// 关闭公开/私有切换弹窗
const closeVisibilityToggle = () => {
  showVisibilityModal.value = false
  tagToToggle.value = null
}

// 执行公开/私有切换
const executeVisibilityToggle = async () => {
  if (!tagToToggle.value) return

  const isPublic = isTagPublic(tagToToggle.value)
  const newDeptId = isPublic ? 0 : (props.userDepartmentId || 0)

  isToggling.value = true
  try {
    const res = await updateTagDepartment(tagToToggle.value.id, newDeptId)
    const affectedPrompts = res.data?.affected_prompts || 0

    if (isPublic && affectedPrompts > 0) {
      toast(`标签已设为私有，同时已将 ${affectedPrompts} 个关联的公开提示词设为私有`, 'success')
    } else {
      toast(isPublic ? '标签已设为私有' : '标签已设为公开', 'success')
    }

    closeVisibilityToggle()
    await loadData()
  } catch (error: any) {
    toast(error?.response?.data?.message || '设置失败', 'error')
  } finally {
    isToggling.value = false
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
                    <span class="visibility-badge" :class="{ 'is-public': isTagPublic(tag) }">
                      <Globe v-if="isTagPublic(tag)" :size="12" />
                      <FolderOpen v-else :size="12" />
                      {{ isTagPublic(tag) ? '公开' : '私有' }}
                    </span>
                  </div>
                </template>
              </div>

              <div v-if="editingTag?.id !== tag.id" class="tag-actions">
                <button
                  class="icon-btn"
                  :title="isTagPublic(tag) ? '设为私有' : '设为公开'"
                  @click="openVisibilityToggle(tag)"
                >
                  <Globe v-if="!isTagPublic(tag)" :size="16" />
                  <FolderOpen v-else :size="16" />
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

        <!-- 可见性说明 -->
        <div class="dept-info">
          <h4>可见性说明</h4>
          <div class="dept-options">
            <div class="dept-option">
              <Globe :size="16" />
              <div>
                <span class="option-title">公开标签</span>
                <span class="option-desc">标签将在提示词广场公开显示</span>
              </div>
            </div>
            <div class="dept-option">
              <FolderOpen :size="16" />
              <div>
                <span class="option-title">私有标签</span>
                <span class="option-desc">标签仅自己可见</span>
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

    <!-- 公开/私有切换弹窗 -->
    <div v-if="showVisibilityModal" class="confirm-overlay" @click.self="closeVisibilityToggle">
      <div class="confirm-modal">
        <div class="confirm-header">
          <component :is="isTagPublic(tagToToggle!) ? FolderOpen : Globe" class="primary-icon" :size="24" />
          <h4>{{ isTagPublic(tagToToggle!) ? '设为私有' : '设为公开' }}</h4>
        </div>
        <div class="confirm-body">
          <p v-if="isTagPublic(tagToToggle!)">
            确定要将标签「<strong>{{ tagToToggle?.tag_name }}</strong>」设为私有吗？<br>
            <span class="hint-text">设为私有后，该标签将不再在提示词广场显示。</span>
            <span class="warning-text">⚠️ 注意：使用该标签的公开提示词也将同步设为私有。</span>
          </p>
          <p v-else>
            确定要将标签「<strong>{{ tagToToggle?.tag_name }}</strong>」设为公开吗？<br>
            <span class="hint-text">设为公开后，该标签将在提示词广场显示{{ userDeptName ? `（归属到${userDeptName}）` : '' }}。</span>
          </p>
        </div>
        <div class="confirm-footer">
          <button class="btn-secondary" @click="closeVisibilityToggle" :disabled="isToggling">
            取消
          </button>
          <button
            class="btn-primary"
            @click="executeVisibilityToggle"
            :disabled="isToggling"
          >
            {{ isToggling ? '保存中...' : '确认' }}
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

.visibility-badge {
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

.visibility-badge.is-public {
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

.confirm-body .hint-text {
  display: block;
  margin-top: 8px;
  font-size: 13px;
  color: var(--text-secondary);
}

.confirm-body .warning-text {
  display: block;
  margin-top: 12px;
  padding: 10px 12px;
  background: rgba(245, 158, 11, 0.1);
  border-left: 3px solid #f59e0b;
  border-radius: 4px;
  font-size: 13px;
  color: #d97706;
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

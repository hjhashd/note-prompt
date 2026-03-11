<script setup lang="ts">
import { ref, onMounted, onActivated, computed, watch } from 'vue'
import { X, AlertTriangle, ChevronDown, ChevronUp } from 'lucide-vue-next'
import { getTagsTree, getUserTagsTree } from '@/api/prompt'
import { getPythonTagsTree, deletePersonalTag, deletePublicTag } from '@/api/promptSave'
import { useToast } from '@/composables/useToast'
import type { TagItem } from '@/types/prompt'

const props = defineProps<{
  modelValue: number | number[] | null,
  parentId?: number | null,
  type?: 'public' | 'user',
  enableDrag?: boolean
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', id: number | number[] | null): void
  (e: 'select', payload: { id: number | number[] | null, node?: TagItem })
  (e: 'tagDeleted', tagId: number): void
}>()

const { toast } = useToast()
const currentUserId = ref<number | null>(null)
const isLoading = ref(false)

const fullTree = ref<TagItem[]>([]) // Store raw tree (departments)
const personalTags = ref<TagItem[]>([]) // Store personal tags (type=2)
const childTags = ref<TagItem[]>([]) // Tags to display (children of parent)

// Helper to find a node by ID
const findNode = (nodes: TagItem[], targetId: number): TagItem | null => {
  for (const node of nodes) {
    if (node.id === targetId) return node
    if (node.children) {
      const found = findNode(node.children, targetId)
      if (found) return found
    }
  }
  return null
}

// Get all descendant department IDs (including self)
const getDescendantIds = (nodes: TagItem[], targetId: number): number[] => {
  const result: number[] = [targetId]
  const node = findNode(nodes, targetId)
  if (node && node.children) {
    for (const child of node.children) {
      result.push(...getDescendantIds(nodes, child.id))
    }
  }
  return result
}

const updateChildTags = () => {
  let sourceNodes: TagItem[] = []

  if (props.type === 'user') {
    // For user tags, show all tags directly (no department hierarchy)
    sourceNodes = [...personalTags.value]
  } else if (props.parentId) {
    // When a department is selected, only show personal tags under this department
    // Don't show child departments (they are already shown in the left sidebar)
    const descendantIds = getDescendantIds(fullTree.value, props.parentId)
    console.log('[TiledCategoryFilter] parentId:', props.parentId, 'descendantIds:', descendantIds, 'totalTags:', personalTags.value.length)

    // Only show personal tags that have department_id matching any descendant
    const matchingPersonalTags = personalTags.value.filter(
      tag => tag.departmentId && descendantIds.includes(tag.departmentId)
    )
    console.log('[TiledCategoryFilter] matching tags:', matchingPersonalTags.length)
    sourceNodes = [...matchingPersonalTags]
  } else {
    // When "All Departments" is selected (parentId is null), show all personal tags
    sourceNodes = [...personalTags.value]
  }

  childTags.value = sourceNodes
}

// Watch parentId to update available tags
watch(() => props.parentId, () => {
  updateChildTags()
})

const fetchTags = async () => {
  if (isLoading.value) return
  isLoading.value = true
  try {
    if (props.type === 'user') {
      // For user tags, fetch from Java backend (getUserTagsTree)
      const data = await getUserTagsTree()
      fullTree.value = data
      // For user type, personalTags is the flattened user tags
      const flattenTags = (nodes: TagItem[]): TagItem[] => {
        return nodes.reduce((acc: TagItem[], node) => {
          acc.push(node)
          if (node.children && node.children.length > 0) {
            acc.push(...flattenTags(node.children))
          }
          return acc
        }, [])
      }
      personalTags.value = flattenTags(data)
      console.log('[TiledCategoryFilter] User tags loaded:', personalTags.value)
    } else {
      // For public tags, fetch department tree from Java backend
      const data = await getTagsTree()
      // Keep full tree for descendant lookup, but also unwrap for display if needed
      // Store the complete tree structure for proper descendant ID lookup
      fullTree.value = data || []
      console.log('[TiledCategoryFilter] Department tree loaded:', fullTree.value)

      // Also fetch personal tags from Python backend (to get type=2 tags with department_id)
      // For public plaza, include_all_public=true to get all tags with department_id
      try {
        const pythonData = await getPythonTagsTree(true, true)
        // Flatten personal tags and convert to TagItem format
        const flattenTags = (nodes: any[]): TagItem[] => {
          return nodes.reduce((acc: TagItem[], node) => {
            acc.push({
              id: node.id,
              name: node.tag_name,
              parentId: node.parent_id,
              departmentId: node.department_id,
              children: node.children ? flattenTags(node.children) : [],
              sortOrder: 0
            })
            if (node.children && node.children.length > 0) {
              acc.push(...flattenTags(node.children))
            }
            return acc
          }, [])
        }
        // Use public_tags for plaza (all tags with department_id)
        personalTags.value = flattenTags(pythonData.public_tags || [])
        console.log('[TiledCategoryFilter] Public tags loaded:', personalTags.value)
      } catch (err) {
        console.error('[TiledCategoryFilter] Failed to fetch public tags:', err)
      }
    }

    updateChildTags()
  } catch (error) {
    console.error('Failed to fetch tags:', error)
  } finally {
    isLoading.value = false
  }
}

onMounted(() => {
  fetchTags()
})

onActivated(() => {
  fetchTags()
})

// Current active selection logic
const activeTagId = computed(() => {
  return props.modelValue
})

const handleSelect = (id: number | null, node?: TagItem) => {
  if (id === null) {
    // "All" clicked - clear all selections
    emit('update:modelValue', null)
    emit('select', { id: null, node: undefined })
    return
  }

  let newValue: number | number[] | null = null

  if (props.modelValue === null) {
    // Nothing selected, start with an array containing the new ID
    newValue = [id]
  } else if (Array.isArray(props.modelValue)) {
    // Already an array, toggle the ID
    if (props.modelValue.includes(id)) {
      newValue = props.modelValue.filter(v => v !== id)
      if (newValue.length === 0) newValue = null
    } else {
      newValue = [...props.modelValue, id]
    }
  } else {
    // Single number selected, toggle or convert to array
    if (props.modelValue === id) {
      newValue = null
    } else {
      newValue = [props.modelValue, id]
    }
  }

  emit('update:modelValue', newValue)
  emit('select', { id: newValue, node })
}

// 标签删除相关
const showDeleteTagModal = ref(false)
const tagToDelete = ref<TagItem | null>(null)
const isDeletingTag = ref(false)

// 标签折叠相关
const isExpanded = ref(false)
const MAX_VISIBLE_TAGS = 16 // 默认显示的标签数量

const visibleTags = computed(() => {
  if (isExpanded.value || childTags.value.length <= MAX_VISIBLE_TAGS) {
    return childTags.value
  }
  return childTags.value.slice(0, MAX_VISIBLE_TAGS)
})

const hiddenCount = computed(() => {
  return Math.max(0, childTags.value.length - MAX_VISIBLE_TAGS)
})

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value
}

// 拖拽相关
const draggedTag = ref<TagItem | null>(null)

const handleDragStart = (e: DragEvent, item: TagItem) => {
  console.log('[TiledCategoryFilter] Drag start:', item)
  draggedTag.value = item
  // 设置拖拽数据
  if (e.dataTransfer) {
    e.dataTransfer.effectAllowed = 'copy'
    const dragData = JSON.stringify({
      tagId: item.id,
      tagName: item.name
    })
    console.log('[TiledCategoryFilter] Drag data:', dragData)
    e.dataTransfer.setData('application/json', dragData)
    // 同时设置纯文本，增加兼容性
    e.dataTransfer.setData('text/plain', dragData)
    // 设置自定义拖拽图像（可选）
    const el = e.target as HTMLElement
    if (el) {
      e.dataTransfer.setDragImage(el, 20, 20)
    }
  }
}

const handleDragEnd = () => {
  draggedTag.value = null
}

// 判断是否可以删除标签（用户自己创建的标签）
const canDeleteTag = (tag: TagItem): boolean => {
  // 个人标签都可以删除
  if (props.type === 'user') return true
  // 公共标签需要检查是否是自己创建的（这里简化处理，实际应该根据user_id判断）
  return false
}

// 显示删除标签弹窗
const handleDeleteTagClick = (e: Event, tag: TagItem) => {
  e.stopPropagation()
  tagToDelete.value = tag
  showDeleteTagModal.value = true
}

// 取消删除标签
const cancelDeleteTag = () => {
  showDeleteTagModal.value = false
  tagToDelete.value = null
}

// 确认删除标签
const confirmDeleteTag = async () => {
  if (!tagToDelete.value) return

  isDeletingTag.value = true
  try {
    const tagId = tagToDelete.value.id

    if (props.type === 'user') {
      await deletePersonalTag(tagId, false)
    } else {
      await deletePublicTag(tagId, false)
    }

    toast('标签删除成功', 'success')
    emit('tagDeleted', tagId)
    
    // 如果删除的是当前选中的标签，从选择中移除
    if (Array.isArray(props.modelValue)) {
      if (props.modelValue.includes(tagId)) {
        const newValue = props.modelValue.filter(id => id !== tagId)
        const emitValue = newValue.length > 0 ? newValue : null
        emit('update:modelValue', emitValue)
        emit('select', { id: emitValue, node: undefined })
      }
    } else if (props.modelValue === tagId) {
      emit('update:modelValue', null)
      emit('select', { id: null, node: undefined })
    }
    
    // 刷新标签列表
    await fetchTags()
  } catch (error: any) {
    const message = error?.response?.data?.message || '删除标签失败'
    toast(message, 'error')
  } finally {
    isDeletingTag.value = false
    cancelDeleteTag()
  }
}

</script>

<template>
  <div class="tiled-filter-bar" v-if="childTags.length > 0">
    <!-- 拖拽提示 - 只在启用拖拽时显示 -->
    <div v-if="enableDrag" class="drag-hint">
      <span class="hint-icon">💡</span>
      <span class="hint-text">拖拽标签到提示词卡片上，快速为提示词添加标签</span>
    </div>
    <div class="filter-row">
      <div class="row-options" :class="{ expanded: isExpanded }">
        <button
          class="filter-chip"
          :class="{ active: activeTagId === null }"
          @click="handleSelect(null)"
        >
          全部
        </button>
        <button
          v-for="item in visibleTags"
          :key="item.id"
          class="filter-chip deletable"
          :class="{ 
            active: Array.isArray(activeTagId) ? activeTagId.includes(item.id) : activeTagId === item.id, 
            'draggable': enableDrag,
            'is-dragging': enableDrag && draggedTag?.id === item.id 
          }"
          :draggable="enableDrag"
          @click="handleSelect(item.id, item)"
          @dragstart="enableDrag && handleDragStart($event, item)"
          @dragend="enableDrag && handleDragEnd"
        >
          <span v-if="enableDrag" class="drag-handle" title="拖拽到提示词卡片">⋮⋮</span>
          <span class="tag-name">{{ item.name }}</span>
          <span
            v-if="canDeleteTag(item)"
            class="delete-btn"
            @click="handleDeleteTagClick($event, item)"
            title="删除标签"
          >
            <X :size="14" />
          </span>
        </button>
        <button
          v-if="hiddenCount > 0"
          class="filter-chip expand-btn"
          @click="toggleExpand"
        >
          <span v-if="isExpanded">
            收起 <ChevronUp :size="14" />
          </span>
          <span v-else>
            更多 {{ hiddenCount }} 个 <ChevronDown :size="14" />
          </span>
        </button>
      </div>
    </div>
  </div>

  <!-- 删除标签确认弹窗 -->
  <div v-if="showDeleteTagModal" class="modal-overlay" @click.self="cancelDeleteTag">
    <div class="modal-content">
      <div class="modal-header">
        <AlertTriangle class="warning-icon" :size="24" />
        <h3>删除标签</h3>
      </div>
      <div class="modal-body">
        <p>确定要删除标签「<strong>{{ tagToDelete?.name }}</strong>」吗？</p>
        <p class="delete-hint">删除后，该标签下的提示词将不再归类到此标签</p>
      </div>
      <div class="modal-footer">
        <button class="btn-secondary" @click="cancelDeleteTag" :disabled="isDeletingTag">
          取消
        </button>
        <button 
          class="btn-danger" 
          @click="confirmDeleteTag" 
          :disabled="isDeletingTag"
        >
          {{ isDeletingTag ? '删除中...' : '确认删除' }}
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tiled-filter-bar {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  padding: 16px;
  border: 1px solid var(--border-subtle);
}

.filter-row {
  display: flex;
  align-items: flex-start;
  gap: 16px;
}

.row-options {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  flex: 1;
  max-height: 36px; /* 默认只显示一行 */
  overflow: hidden;
  transition: max-height 0.3s ease;
}

.row-options.expanded {
  max-height: none; /* 展开时无高度限制 */
}

.filter-chip {
  padding: 6px 16px;
  border-radius: 20px;
  font-size: 14px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  border: 1px solid transparent;
  cursor: pointer;
  transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  display: flex;
  align-items: center;
  gap: 6px;
}

.filter-chip:hover {
  color: var(--text-primary);
  background: var(--bg-tertiary);
}

.filter-chip.active {
  color: white;
  background: var(--primary);
  box-shadow: 0 2px 4px rgba(var(--primary-rgb), 0.2);
}

.filter-chip.deletable {
  padding-right: 8px;
}

.filter-chip .tag-name {
  flex: 1;
}

.filter-chip .delete-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: transparent;
  color: inherit;
  opacity: 0.6;
  transition: all 0.2s;
}

.filter-chip .delete-btn:hover {
  background: rgba(0, 0, 0, 0.1);
  opacity: 1;
}

.filter-chip.active .delete-btn:hover {
  background: rgba(255, 255, 255, 0.2);
}

.filter-chip.expand-btn {
  background: transparent;
  border: 1px dashed var(--border-color);
  color: var(--text-secondary);
  font-weight: 500;
}

.filter-chip.expand-btn:hover {
  background: var(--bg-secondary);
  border-color: var(--primary);
  color: var(--primary);
}

/* 拖拽相关样式 */
.drag-hint {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  margin-bottom: 12px;
  background: linear-gradient(135deg, rgba(var(--primary-rgb), 0.08) 0%, rgba(var(--primary-rgb), 0.04) 100%);
  border-radius: 8px;
  border: 1px dashed rgba(var(--primary-rgb), 0.3);
  font-size: 13px;
  color: var(--text-secondary);
}

.hint-icon {
  font-size: 16px;
}

.hint-text {
  flex: 1;
}

.filter-chip.draggable {
  position: relative;
  cursor: grab;
  padding-left: 28px;
}

.filter-chip.draggable:active {
  cursor: grabbing;
}

.filter-chip.draggable.is-dragging {
  transform: scale(1.05) rotate(1.5deg);
  box-shadow: 0 12px 28px rgba(0, 0, 0, 0.15);
  border: 1px solid var(--primary);
  background: var(--bg-surface);
  color: var(--primary);
  z-index: 100;
  cursor: grabbing;
}

.drag-handle {
  position: absolute;
  left: 8px;
  top: 50%;
  transform: translateY(-50%);
  font-size: 10px;
  color: var(--text-tertiary);
  letter-spacing: -2px;
  opacity: 0.6;
  pointer-events: none;
}

.filter-chip.draggable:hover .drag-handle {
  opacity: 1;
  color: var(--primary);
}

/* Modal Styles */
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
  border-radius: 12px;
  padding: 24px;
  min-width: 420px;
  max-width: 90vw;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.modal-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.warning-icon {
  color: #f59e0b;
}

.modal-body {
  margin-bottom: 24px;
}

.modal-body p {
  margin-bottom: 8px;
  color: var(--text-primary);
}

.modal-body .delete-hint {
  font-size: 13px;
  color: var(--text-secondary);
  margin-bottom: 0;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn-secondary, .btn-danger {
  padding: 8px 16px;
  border-radius: 8px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.btn-secondary {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.btn-secondary:hover:not(:disabled) {
  background: var(--bg-tertiary);
}

.btn-danger {
  background: #ef4444;
  color: white;
}

.btn-danger:hover:not(:disabled) {
  background: #dc2626;
}

.btn-secondary:disabled, .btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
</style>

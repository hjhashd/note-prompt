<script setup lang="ts">
import { ref, onMounted, computed, watch } from 'vue'
import { X, AlertTriangle, ChevronDown, ChevronUp } from 'lucide-vue-next'
import { getTagsTree, getUserTagsTree } from '@/api/prompt'
import { getPythonTagsTree, deletePersonalTag, deletePublicTag } from '@/api/promptSave'
import { useToast } from '@/composables/useToast'
import type { TagItem } from '@/types/prompt'

const props = defineProps<{
  modelValue: number | null,
  parentId?: number | null,
  type?: 'public' | 'user'
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', id: number | null): void
  (e: 'select', payload: { id: number | null, node?: TagItem })
  (e: 'tagDeleted', tagId: number): void
}>()

const { toast } = useToast()
const currentUserId = ref<number | null>(null)

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
    // Get child departments
    const parentNode = findNode(fullTree.value, props.parentId)
    if (parentNode) {
      sourceNodes = [...(parentNode.children || [])]
    }
    
    // Get all descendant department IDs (including current department)
    const descendantIds = getDescendantIds(fullTree.value, props.parentId)
    
    // Add personal tags that have department_id matching any descendant
    const matchingPersonalTags = personalTags.value.filter(
      tag => tag.departmentId && descendantIds.includes(tag.departmentId)
    )
    sourceNodes = [...sourceNodes, ...matchingPersonalTags]
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
      // Align with TagDirectory: Unwrap if there's a single root with children
      let roots = data
      if (data && data.length > 0 && data[0].children) {
        roots = data[0].children
      }
      fullTree.value = roots

      // Also fetch personal tags from Python backend (to get type=2 tags with department_id)
      try {
        const pythonData = await getPythonTagsTree(true)
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
        personalTags.value = flattenTags(pythonData.personal_tags || [])
        console.log('[TiledCategoryFilter] Personal tags loaded:', personalTags.value)
      } catch (err) {
        console.error('[TiledCategoryFilter] Failed to fetch personal tags:', err)
      }
    }

    updateChildTags()
  } catch (error) {
    console.error('Failed to fetch tags:', error)
  }
}

onMounted(() => {
  fetchTags()
})

// Current active selection logic
// If modelValue == parentId, it means "All" (no specific child tag selected)
// If modelValue != parentId, it should be one of the child tags
const activeTagId = computed(() => {
  if (props.modelValue === props.parentId) return null // "All" is active
  return props.modelValue
})

const handleSelect = (id: number | null, node?: TagItem) => {
  // Toggle logic: If clicking the currently active tag, deselect it (revert to "All"/null)
  if (id !== null && props.modelValue === id) {
    emit('update:modelValue', null)
    emit('select', { id: null, node: undefined })
    return
  }

  // If id is null, it means "All" was clicked
  emit('update:modelValue', id)
  emit('select', { id, node })
}

// 标签删除相关
const showDeleteTagModal = ref(false)
const tagToDelete = ref<TagItem | null>(null)
const deleteTagWithPrompts = ref(false)
const isDeletingTag = ref(false)

// 标签折叠相关
const isExpanded = ref(false)
const MAX_VISIBLE_TAGS = 8 // 默认显示的标签数量

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
  deleteTagWithPrompts.value = false
  showDeleteTagModal.value = true
}

// 取消删除标签
const cancelDeleteTag = () => {
  showDeleteTagModal.value = false
  tagToDelete.value = null
  deleteTagWithPrompts.value = false
}

// 确认删除标签
const confirmDeleteTag = async () => {
  if (!tagToDelete.value) return
  
  isDeletingTag.value = true
  try {
    const tagId = tagToDelete.value.id
    
    if (props.type === 'user') {
      await deletePersonalTag(tagId, deleteTagWithPrompts.value)
    } else {
      await deletePublicTag(tagId, deleteTagWithPrompts.value)
    }
    
    const actionText = deleteTagWithPrompts.value ? '标签及关联提示词删除成功' : '标签删除成功'
    toast(actionText, 'success')
    emit('tagDeleted', tagId)
    
    // 如果删除的是当前选中的标签，重置选择
    if (props.modelValue === tagId) {
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
          :class="{ active: activeTagId === item.id }"
          @click="handleSelect(item.id, item)"
        >
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
        
        <div class="delete-options">
          <label class="radio-label">
            <input 
              type="radio" 
              v-model="deleteTagWithPrompts" 
              :value="false"
            />
            <div class="radio-content">
              <span class="radio-title">仅删除标签</span>
              <span class="radio-desc">保留标签下的所有提示词，提示词将不再归类到此标签</span>
            </div>
          </label>
          
          <label class="radio-label">
            <input 
              type="radio" 
              v-model="deleteTagWithPrompts" 
              :value="true"
            />
            <div class="radio-content">
              <span class="radio-title">删除标签及关联提示词</span>
              <span class="radio-desc">同时删除该标签下的所有提示词（此操作不可恢复）</span>
            </div>
          </label>
        </div>
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
  transition: all 0.2s;
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
  margin-bottom: 16px;
  color: var(--text-primary);
}

.delete-options {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.radio-label {
  display: flex;
  align-items: flex-start;
  gap: 12px;
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
}

.radio-desc {
  font-size: 13px;
  color: var(--text-secondary);
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

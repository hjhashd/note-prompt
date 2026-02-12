<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { getTagsTree } from '@/api/prompt'
import type { TagItem } from '@/types/prompt'
import * as LucideIcons from 'lucide-vue-next'

const props = withDefaults(defineProps<{ 
  collapsed?: boolean
  modelValue?: number | null 
}>(), {
  collapsed: false,
  modelValue: null
})

const emit = defineEmits<{
  (e: 'toggleCollapse'): void
  (e: 'select', id: number | null): void
  (e: 'update:modelValue', id: number | null): void
}>()

const expandedItems = ref<number[]>([])
const activeCategory = ref<number | null>(props.modelValue)
const searchQuery = ref('')
const categories = ref<TagItem[]>([])

const getIcon = (name: string) => {
  if (!name) return null
  // Map old Element UI icons to Lucide equivalents if needed
  if (name.startsWith('el-icon-')) {
    const map: Record<string, string> = {
      'el-icon-folder': 'Folder',
      'el-icon-office-building': 'Building2',
      'el-icon-document': 'BookOpen'
    }
    name = map[name] || 'Folder'
  }
  return (LucideIcons as any)[name] || LucideIcons.Folder
}

watch(() => props.modelValue, (newVal) => {
  activeCategory.value = newVal
})

const toggleTreeItem = (id: number) => {
  const index = expandedItems.value.indexOf(id)
  if (index > -1) {
    expandedItems.value.splice(index, 1)
  } else {
    expandedItems.value.push(id)
  }
}

const selectCategory = (id: number | null) => {
  // If id is 0 (All Departments), treat as null
  const effectiveId = id === 0 ? null : id
  activeCategory.value = effectiveId
  emit('select', effectiveId)
  emit('update:modelValue', effectiveId)
}

const fetchTags = async () => {
  try {
    const data = await getTagsTree()
    console.log('[TagDirectory] Raw data from API:', JSON.stringify(data, null, 2))
    
    let rootItems = data
    // Flatten root logic: Remove "All Company" top level if present
    if (data && data.length > 0 && data[0].children) {
      console.log('[TagDirectory] First node has children, unwrapping...')
      rootItems = data[0].children
    }
    
    console.log('[TagDirectory] Root items after flatten:', rootItems)
    
    // Filter logic: Recursively keep items that are departments (have departmentId)
    // We create a deep copy with filtering to ensure we don't mutate the original data if referenced elsewhere (though here it's fresh)
    const filterDepartments = (nodes: TagItem[]): TagItem[] => {
      return nodes
        .filter(item => {
          const hasDeptId = item.departmentId !== null && item.departmentId !== undefined
          console.log(`[TagDirectory] Filtering item ${item.name} (id=${item.id}): departmentId=${item.departmentId}, hasDeptId=${hasDeptId}`)
          return hasDeptId
        })
        .map(item => ({
          ...item,
          children: item.children ? filterDepartments(item.children) : []
        }))
    }

    const deptItems = filterDepartments(rootItems)
    console.log('[TagDirectory] Filtered deptItems:', deptItems)
    console.log('[TagDirectory] deptItems length:', deptItems.length)

    // Add "All Departments" node
    const allDeptNode: TagItem = {
      id: 0, // Special ID for UI handling, maps to null
      name: '全部部门',
      icon: 'LayoutGrid', // Uses Lucide icon
      children: []
    }
    
    categories.value = [allDeptNode, ...deptItems]
    console.log('[TagDirectory] Final categories:', categories.value)
    
    // Expand root items by default (excluding 'All' if it has no children, which it doesn't)
    expandedItems.value = deptItems.map(item => item.id)
  } catch (error) {
    console.error('Failed to fetch tags:', error)
  }
}

onMounted(() => {
  fetchTags()
})
</script>

<template>
  <div class="tag-directory" :class="{ collapsed: props.collapsed }">
    <div class="directory-header">
      <div class="header-row">
        <h2 class="directory-title" v-if="!props.collapsed">部门分类</h2>
        <button
          class="collapse-btn"
          type="button"
          :title="props.collapsed ? '展开分类目录' : '收起分类目录'"
          @click="emit('toggleCollapse')"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polyline v-if="!props.collapsed" points="15 18 9 12 15 6"></polyline>
            <polyline v-else points="9 18 15 12 9 6"></polyline>
          </svg>
        </button>
      </div>

      <div v-if="!props.collapsed" class="search-box">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" class="search-icon">
          <circle cx="11" cy="11" r="8"></circle>
          <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
        </svg>
        <input 
          type="text" 
          v-model="searchQuery" 
          placeholder="搜索分类..."
          class="search-input"
        >
      </div>
    </div>

    <div v-if="!props.collapsed" class="directory-content custom-scrollbar">
      <div class="tree-root">
        <template v-for="category in categories" :key="category.id">
          <!-- Root Item -->
          <div class="tree-item-wrapper">
            <div 
              class="tree-item root-item"
              :class="{ active: (category.id === 0 && activeCategory === null) || activeCategory === category.id }"
              @click="selectCategory(category.id)"
            >
              <span class="expand-icon" 
                :class="{ hidden: !category.children || category.children.length === 0 }"
                @click.stop="toggleTreeItem(category.id)"
              >
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                  :style="{ transform: expandedItems.includes(category.id) ? 'rotate(90deg)' : 'rotate(0)' }"
                >
                  <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
              </span>
              <span class="item-name">{{ category.name }}</span>
              <span class="item-count" v-if="category.count">{{ category.count }}</span>
            </div>

            <!-- Children -->
            <div class="tree-children" v-if="expandedItems.includes(category.id)">
              <div v-for="child in category.children" :key="child.id" class="child-wrapper">
                <div 
                  class="tree-item child-item"
                  :class="{ active: activeCategory === child.id }"
                  @click="selectCategory(child.id)"
                >
                  <span class="expand-icon" 
                    :class="{ hidden: !child.children || child.children.length === 0 }"
                    @click.stop="toggleTreeItem(child.id)"
                  >
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                      :style="{ transform: expandedItems.includes(child.id) ? 'rotate(90deg)' : 'rotate(0)' }"
                    >
                      <polyline points="9 18 15 12 9 6"></polyline>
                    </svg>
                  </span>
                  <span class="item-name">{{ child.name }}</span>
                  <span class="item-count" v-if="child.count">{{ child.count }}</span>
                </div>

                <!-- Grandchildren -->
                <div class="tree-children" v-if="expandedItems.includes(child.id) && child.children">
                  <div 
                    v-for="subChild in child.children" 
                    :key="subChild.id"
                    class="tree-item grandchild-item"
                    :class="{ active: activeCategory === subChild.id }"
                    @click="selectCategory(subChild.id)"
                  >
                    <span class="item-name">{{ subChild.name }}</span>
                    <span class="item-count" v-if="subChild.count">{{ subChild.count }}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </template>
      </div>
    </div>
  </div>
</template>

<style scoped>
.tag-directory {
  background: var(--bg-surface);
  border-radius: var(--radius-xl);
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  box-shadow: var(--shadow-md);
  transition: all var(--transition-normal);
}

.tag-directory.collapsed {
  background: transparent;
  border-color: transparent;
  box-shadow: none;
}

.directory-header {
  padding: 20px;
  border-bottom: 1px solid var(--bg-primary);
}

.tag-directory.collapsed .directory-header {
  padding: 8px 0;
  border-bottom: none;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.header-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 12px;
  margin-bottom: 16px;
  width: 100%;
}

.tag-directory.collapsed .header-row {
  margin-bottom: 0;
  justify-content: center;
}

.directory-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
  white-space: nowrap;
}

.collapse-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.collapse-btn:hover {
  background: rgba(0,0,0,0.05);
  color: var(--text-primary);
}

.search-box {
  position: relative;
}

.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-tertiary);
}

.search-input {
  width: 100%;
  padding: 8px 12px 8px 36px;
  border: none;
  border-radius: 24px; /* Pill Shape */
  font-size: 14px;
  background: var(--bg-secondary);
  color: var(--text-primary);
  transition: all var(--transition-fast);
}

.search-input:focus {
  outline: none;
  background: var(--bg-primary);
}

.directory-content {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
}

/* Tree Items */
.tree-item {
  display: flex;
  align-items: center;
  padding: 10px 12px;
  border-radius: 24px; /* Pill shape for items */
  cursor: pointer;
  transition: all var(--transition-fast);
  margin-bottom: 2px;
  color: var(--text-secondary);
  font-size: 14px;
}

.tree-item:hover {
  background: rgba(0,0,0,0.05);
  color: var(--text-primary);
}

.tree-item.active {
  background: var(--primary-light);
  color: var(--primary);
  font-weight: 500;
}

.root-item {
  font-weight: 500;
}

.child-item {
  padding-left: 28px;
}

.grandchild-item {
  padding-left: 48px;
  font-size: 13px;
}

.expand-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  margin-right: 4px;
  color: var(--gray-400);
  transition: color var(--transition-fast);
}

.expand-icon:hover {
  color: var(--gray-600);
}

.expand-icon.hidden {
  opacity: 0;
  pointer-events: none;
}

.expand-icon svg {
  transition: transform var(--transition-fast);
}

.item-icon {
  margin-right: 8px;
  color: var(--gray-400);
}

.tree-item.active .item-icon {
  color: var(--primary-500);
}

.item-name {
  flex: 1;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.item-count {
  font-size: 12px;
  color: var(--gray-400);
  background: var(--gray-100);
  padding: 2px 6px;
  border-radius: 10px;
  min-width: 24px;
  text-align: center;
}

.tree-item.active .item-count {
  background: var(--primary-100);
  color: var(--primary-600);
}

.tree-children {
  position: relative;
}

/* Connecting lines for tree structure - optional, keeping clean for now */
</style>

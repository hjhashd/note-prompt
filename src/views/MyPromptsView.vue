<script setup lang="ts">
import { ref, provide, onMounted, onActivated, nextTick, onBeforeUnmount } from 'vue'
import { useRouter, onBeforeRouteLeave } from 'vue-router'
import { Plus, Trash2, X, AlertTriangle, Share2, Settings, Tag, FolderOpen, Search, ArrowUpDown } from 'lucide-vue-next'
import { useAppStore } from '@/stores/app'
import { useChatStore } from '@/stores/chat'
import { useToast } from '@/composables/useToast'
import { useUserStore } from '@/stores/user'
import PromptList from '@/components/layout/PromptList.vue'
import TiledCategoryFilter from '@/components/prompt/TiledCategoryFilter.vue'
import TagManageModal from '@/components/prompt/TagManageModal.vue'
import { getPythonTagsTree, addTagToPrompt, removeTagFromPrompt } from '@/api/promptSave'
import type { PromptItem } from '@/types/prompt'

const router = useRouter()
const appStore = useAppStore()
const chatStore = useChatStore()
const userStore = useUserStore()
const { toast } = useToast()
const currentTagId = ref<number | number[] | null>(null)
const searchQuery = ref('')
const activeFilter = ref('all')
const activeSort = ref('updatedAt')
const searchInputRef = ref<HTMLInputElement | null>(null)

const filters = [
  { id: 'all', label: '全部' },
  { id: 'my', label: '私有提示词' },
  { id: 'favorites', label: '我的收藏' },
  { id: 'shared', label: '公共分享' }
]

const sortOptions = [
  { value: 'updatedAt', label: '最近更新' },
  { value: 'createdAt', label: '创建时间' },
  { value: 'views', label: '最多浏览' },
  { value: 'likes', label: '最多收藏' }
]

// 标签管理弹窗状态
const showTagManageModal = ref(false)
const contentBodyRef = ref<HTMLElement | null>(null)
const scrollStorageKey = 'scroll:my-prompts'

const restoreScroll = async () => {
  const saved = sessionStorage.getItem(scrollStorageKey)
  if (!contentBodyRef.value || saved === null) return
  await nextTick()
  const el = contentBodyRef.value
  const target = Number(saved)
  const max = Math.max(0, el.scrollHeight - el.clientHeight)
  el.scrollTop = Math.min(target, max)
}

const saveScroll = () => {
  if (!contentBodyRef.value) return
  sessionStorage.setItem(scrollStorageKey, String(contentBodyRef.value.scrollTop))
}

// 批量删除模式
const isDeleteMode = ref(false)
const selectedPrompts = ref<Set<number>>(new Set())
const showDeleteConfirm = ref(false)
const deleteWithSession = ref(false)

// 批量分享模式
const isShareMode = ref(false)
const showShareConfirm = ref(false)

// 批量标签管理模式
const isBatchTagMode = ref(false)
const showBatchTagModal = ref(false)
const batchTagSelected = ref<number | null>(null)
const userTags = ref<any[]>([])
const loadingTags = ref(false)
const batchTagMode = ref<'add' | 'remove'>('add') // 'add' 或 'remove'

const createPrompt = () => {
  chatStore.openDraftSession()
  router.push('/studio')
}

// 切换删除模式
const toggleDeleteMode = () => {
  if (isShareMode.value) {
    isShareMode.value = false
    selectedPrompts.value.clear()
  }
  if (isBatchTagMode.value) {
    isBatchTagMode.value = false
    selectedPrompts.value.clear()
  }
  isDeleteMode.value = !isDeleteMode.value
  if (!isDeleteMode.value) {
    selectedPrompts.value.clear()
  }
}

// 切换分享模式
const toggleShareMode = () => {
  if (isDeleteMode.value) {
    isDeleteMode.value = false
    selectedPrompts.value.clear()
  }
  if (isBatchTagMode.value) {
    isBatchTagMode.value = false
    selectedPrompts.value.clear()
  }
  isShareMode.value = !isShareMode.value
  if (!isShareMode.value) {
    selectedPrompts.value.clear()
  }
}

// 切换批量标签模式
const toggleBatchTagMode = () => {
  if (isDeleteMode.value) {
    isDeleteMode.value = false
    selectedPrompts.value.clear()
  }
  if (isShareMode.value) {
    isShareMode.value = false
    selectedPrompts.value.clear()
  }
  isBatchTagMode.value = !isBatchTagMode.value
  if (!isBatchTagMode.value) {
    selectedPrompts.value.clear()
  }
}

const handleBatchShareClick = async () => {
  if (isDeleteMode.value) {
    isDeleteMode.value = false
    selectedPrompts.value.clear()
  }
  if (isBatchTagMode.value) {
    isBatchTagMode.value = false
    selectedPrompts.value.clear()
  }

  if (promptListRef.value) {
    await promptListRef.value.setActiveFilter('my')
    await nextTick()
  }

  if (!isShareMode.value) {
    toggleShareMode()
    toast('已进入批量分享模式，已自动切换到“私有提示词”视图，请点击卡片选择要分享的提示词', 'info')
    if (contentBodyRef.value) {
      contentBodyRef.value.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }
}

// 进入批量标签模式
const enterBatchTagMode = async () => {
  if (isDeleteMode.value) {
    isDeleteMode.value = false
    selectedPrompts.value.clear()
  }
  if (isShareMode.value) {
    isShareMode.value = false
    selectedPrompts.value.clear()
  }

  if (promptListRef.value) {
    await promptListRef.value.setActiveFilter('my')
    await nextTick()
  }

  if (!isBatchTagMode.value) {
    toggleBatchTagMode()
    toast('已进入批量管理标签模式，已自动切换到“私有提示词”视图，请点击卡片选择要管理标签的提示词', 'info')
    if (contentBodyRef.value) {
      contentBodyRef.value.scrollTo({ top: 0, behavior: 'smooth' })
    }
  }
}

// 打开批量标签弹窗
const openBatchTagModal = async () => {
  if (selectedPrompts.value.size === 0) {
    toast('请先选择要添加标签的提示词', 'warning')
    return
  }

  // 加载个人标签
  loadingTags.value = true
  try {
    const res = await getPythonTagsTree(true)
    const allTags: any[] = []
    const flattenTags = (nodes: any[]) => {
      nodes.forEach(node => {
        allTags.push(node)
        if (node.children && node.children.length > 0) {
          flattenTags(node.children)
        }
      })
    }
    // 只加载个人标签
    if (res.personal_tags) flattenTags(res.personal_tags)
    userTags.value = allTags
    batchTagSelected.value = null
    showBatchTagModal.value = true
  } catch (error) {
    console.error('Failed to load tags:', error)
    toast('加载标签失败', 'error')
  } finally {
    loadingTags.value = false
  }
}

// 执行批量添加标签
const executeBatchAddTag = async () => {
  if (!batchTagSelected.value || selectedPrompts.value.size === 0) return

  const tag = userTags.value.find(t => t.id === batchTagSelected.value)
  if (!tag) return

  try {
    const promptIds = Array.from(selectedPrompts.value)
    let successCount = 0
    let skipCount = 0

    for (const promptId of promptIds) {
      try {
        await addTagToPrompt(promptId, batchTagSelected.value)
        successCount++
      } catch (error: any) {
        if (error?.response?.data?.message?.includes('已关联')) {
          skipCount++
        }
      }
    }

    if (successCount > 0) {
      toast(`成功为 ${successCount} 个提示词添加标签「${tag.tag_name}」`, 'success')
    }
    if (skipCount > 0) {
      toast(`${skipCount} 个提示词已拥有该标签`, 'info')
    }

    // 关闭弹窗并退出批量模式
    showBatchTagModal.value = false
    batchTagSelected.value = null
    batchTagMode.value = 'add'
    isBatchTagMode.value = false
    selectedPrompts.value.clear()

    // 刷新列表
    if (promptListRef.value) {
      promptListRef.value.fetchPromptsList()
    }
  } catch (error: any) {
    toast(error?.response?.data?.message || '批量添加标签失败', 'error')
  }
}

// 执行批量删除标签
const executeBatchRemoveTag = async () => {
  if (!batchTagSelected.value || selectedPrompts.value.size === 0) return

  const tag = userTags.value.find(t => t.id === batchTagSelected.value)
  if (!tag) return

  try {
    const promptIds = Array.from(selectedPrompts.value)
    let successCount = 0
    let skipCount = 0

    for (const promptId of promptIds) {
      try {
        await removeTagFromPrompt(promptId, batchTagSelected.value)
        successCount++
      } catch (error: any) {
        if (error?.response?.data?.message?.includes('未关联')) {
          skipCount++
        }
      }
    }

    if (successCount > 0) {
      toast(`成功从 ${successCount} 个提示词移除标签「${tag.tag_name}」`, 'success')
    }
    if (skipCount > 0) {
      toast(`${skipCount} 个提示词未拥有该标签`, 'info')
    }

    // 关闭弹窗并退出批量模式
    showBatchTagModal.value = false
    batchTagSelected.value = null
    batchTagMode.value = 'add'
    isBatchTagMode.value = false
    selectedPrompts.value.clear()

    // 刷新列表
    if (promptListRef.value) {
      promptListRef.value.fetchPromptsList()
    }
  } catch (error: any) {
    toast(error?.response?.data?.message || '批量删除标签失败', 'error')
  }
}

// 取消批量标签
const cancelBatchTag = () => {
  showBatchTagModal.value = false
  batchTagSelected.value = null
  batchTagMode.value = 'add'
}

// 取消批量标签模式
const cancelBatchTagMode = () => {
  isBatchTagMode.value = false
  selectedPrompts.value.clear()
}

// 选择/取消选择提示词
const togglePromptSelection = (promptId: number) => {
  const newSet = new Set(selectedPrompts.value)
  if (newSet.has(promptId)) {
    newSet.delete(promptId)
  } else {
    newSet.add(promptId)
  }
  selectedPrompts.value = newSet
}

// 确认删除
const confirmDelete = () => {
  if (selectedPrompts.value.size === 0) {
    toast('请先选择要删除的提示词', 'warning')
    return
  }
  showDeleteConfirm.value = true
}

// 确认分享
const confirmShare = () => {
  if (selectedPrompts.value.size === 0) {
    toast('请先选择要分享的提示词', 'warning')
    return
  }
  showShareConfirm.value = true
}

// 执行删除
const promptListRef = ref<InstanceType<typeof PromptList> | null>(null)

// 标签删除后刷新提示词列表
const onTagDeleted = () => {
  if (promptListRef.value) {
    promptListRef.value.fetchPromptsList()
  }
}

const executeDelete = async () => {
  if (!promptListRef.value) return
  
  await promptListRef.value.deleteSelectedPrompts(deleteWithSession.value)
  showDeleteConfirm.value = false
  deleteWithSession.value = false
  isDeleteMode.value = false
}

// 执行分享
const executeShare = async () => {
  if (!promptListRef.value) return
  
  await promptListRef.value.shareSelectedPrompts()
  showShareConfirm.value = false
  isShareMode.value = false
}

// 取消删除
const cancelDelete = () => {
  showDeleteConfirm.value = false
  deleteWithSession.value = false
}

// 取消分享
const cancelShare = () => {
  showShareConfirm.value = false
}

// 提供给子组件
provide('isDeleteMode', isDeleteMode)
provide('isShareMode', isShareMode)
provide('isBatchTagMode', isBatchTagMode)
provide('selectedPrompts', selectedPrompts)
provide('togglePromptSelection', togglePromptSelection)

const onGlobalKeydown = (e: KeyboardEvent) => {
  const key = e.key.toLowerCase()
  const isK = key === 'k'
  const modifierPressed = e.ctrlKey || e.metaKey
  if (!modifierPressed || !isK) return

  e.preventDefault()
  searchInputRef.value?.focus()
}

onMounted(() => {
  restoreScroll()
  window.addEventListener('keydown', onGlobalKeydown)
})
onActivated(() => {
  restoreScroll()
})
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onGlobalKeydown)
})
onBeforeRouteLeave(() => {
  saveScroll()
})
</script>

<template>
  <div class="view-wrapper">
    <!-- Main Content Area -->
    <div class="content-body" ref="contentBodyRef">
      <div class="content-container">
        <div class="page-header">
          <div class="header-content">
            <h1 class="page-title">我的提示词</h1>
            <p class="page-desc">管理和组织你的个人提示词库，快速访问和复用</p>
          </div>
          <div class="header-actions">
            <button 
              v-if="!isShareMode && !isDeleteMode"
              class="btn-secondary" 
              @click="handleBatchShareClick"
            >
              <Share2 :size="18" />
              <span>批量分享</span>
            </button>
            
            <template v-if="isShareMode">
              <span class="selected-count">已选择 {{ selectedPrompts.size }} 个</span>
              <button class="btn-primary" @click="confirmShare" :disabled="selectedPrompts.size === 0">
                <Share2 :size="18" />
                <span>确认分享</span>
              </button>
              <button class="btn-secondary" @click="toggleShareMode">
                <X :size="18" />
                <span>取消</span>
              </button>
            </template>

            <button
              v-if="!isDeleteMode && !isShareMode && !isBatchTagMode"
              class="btn-secondary"
              @click="showTagManageModal = true"
            >
              <Tag :size="18" />
              <span>标签管理</span>
            </button>

            <button
              v-if="!isDeleteMode && !isShareMode && !isBatchTagMode"
              class="btn-secondary"
              @click="enterBatchTagMode"
            >
              <Tag :size="18" />
              <span>批量管理标签</span>
            </button>

            <button
              v-if="!isDeleteMode && !isShareMode && !isBatchTagMode"
              class="btn-secondary"
              @click="toggleDeleteMode"
            >
              <Trash2 :size="18" />
              <span>批量删除</span>
            </button>

            <template v-if="isBatchTagMode">
              <span class="selected-count">已选择 {{ selectedPrompts.size }} 个</span>
              <button class="btn-primary" @click="openBatchTagModal" :disabled="selectedPrompts.size === 0">
                <Tag :size="18" />
                <span>管理标签</span>
              </button>
              <button class="btn-secondary" @click="cancelBatchTagMode">
                <X :size="18" />
                <span>取消</span>
              </button>
            </template>

            <template v-if="isDeleteMode">
              <span class="selected-count">已选择 {{ selectedPrompts.size }} 个</span>
              <button class="btn-danger" @click="confirmDelete" :disabled="selectedPrompts.size === 0">
                <Trash2 :size="18" />
                <span>确认删除</span>
              </button>
              <button class="btn-secondary" @click="toggleDeleteMode">
                <X :size="18" />
                <span>取消</span>
              </button>
            </template>

            <button class="btn-primary" @click="createPrompt" v-if="!isShareMode && !isDeleteMode && !isBatchTagMode">
              <Plus :size="20" />
              <span>新建提示词</span>
            </button>
          </div>
        </div>

        <div class="sticky-header">
          <div class="tools-section">
            <TiledCategoryFilter v-model="currentTagId" type="user" :enable-drag="true" @tagDeleted="onTagDeleted" />
          </div>

          <!-- Toolbar -->
          <div class="toolbar">
            <div class="search-section">
              <div class="search-input-wrapper">
                <Search class="search-icon" :size="20" />
                <input 
                  type="text" 
                  v-model="searchQuery" 
                  placeholder="在列表中搜索..."
                  class="main-search-input"
                  ref="searchInputRef"
                >
                <div class="search-shortcut" aria-hidden="true">
                  <kbd>Ctrl</kbd>
                  <span class="kbd-plus">+</span>
                  <kbd>K</kbd>
                </div>
              </div>
            </div>
            
            <div class="filter-section">
              <div class="filter-tabs">
                <button 
                  v-for="filter in filters" 
                  :key="filter.id"
                  class="filter-tab"
                  :class="{ active: activeFilter === filter.id }"
                  @click="activeFilter = filter.id"
                >
                  {{ filter.label }}
                </button>
              </div>
              
              <div class="sort-selector">
                <span class="sort-label">排序:</span>
                <div class="select-wrapper">
                  <select v-model="activeSort" class="sort-select">
                    <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                      {{ opt.label }}
                    </option>
                  </select>
                  <ArrowUpDown class="select-icon" :size="14" />
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Prompt List -->
        <div class="list-container">
          <PromptList 
            :is-sidebar-collapsed="appStore.isSidebarCollapsed" 
            :tag-id="currentTagId"
            :filter="activeFilter"
            :search="searchQuery"
            :sort="activeSort"
            :hide-toolbar="true"
            ref="promptListRef"
          /></div>
          </div>
        </div>

    <!-- 删除确认弹窗 -->   <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="cancelDelete">
      <div class="modal-content">
        <div class="modal-header">
          <AlertTriangle class="warning-icon" :size="24" />
          <h3>确认删除</h3>
        </div>
        <div class="modal-body">
          <p>确定要删除选中的 <strong>{{ selectedPrompts.size }}</strong> 个提示词吗？</p>
          <p class="text-secondary">删除后提示词将无法恢复，但数据会保留在系统中。</p>
          
          <label class="checkbox-label">
            <input type="checkbox" v-model="deleteWithSession" />
            <span>同时删除关联的会话记录</span>
          </label>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="cancelDelete">取消</button>
          <button class="btn-danger" @click="executeDelete">确认删除</button>
        </div>
      </div>
    </div>

    <!-- 分享确认弹窗 -->
    <div v-if="showShareConfirm" class="modal-overlay" @click.self="cancelShare">
      <div class="modal-content">
        <div class="modal-header">
          <Share2 class="primary-icon" :size="24" />
          <h3>确认分享</h3>
        </div>
        <div class="modal-body">
          <p>确定要分享选中的 <strong>{{ selectedPrompts.size }}</strong> 个提示词到提示词广场吗？</p>
          <p class="text-secondary">
            分享后，提示词将公开可见，并根据您的部门设置自动分类。
            <br>
            如果没有绑定部门，将分享到公共区域。
          </p>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="cancelShare">取消</button>
          <button class="btn-primary" @click="executeShare">确认分享</button>
        </div>
      </div>
    </div>

    <!-- 标签管理弹窗 -->
    <TagManageModal
      v-model:visible="showTagManageModal"
      :user-department-id="userStore.userInfo?.departmentId"
    />

    <!-- 批量标签弹窗 -->
    <div v-if="showBatchTagModal" class="modal-overlay" @click.self="cancelBatchTag">
      <div class="modal-content batch-tag-modal">
        <div class="modal-header">
          <Tag class="primary-icon" :size="24" />
          <h3>批量标签管理</h3>
        </div>
        <div class="modal-body">
          <!-- 模式切换 -->
          <div class="mode-tabs">
            <button
              class="mode-tab"
              :class="{ active: batchTagMode === 'add' }"
              @click="batchTagMode = 'add'"
            >
              <Plus :size="16" />
              <span>添加标签</span>
            </button>
            <button
              class="mode-tab"
              :class="{ active: batchTagMode === 'remove' }"
              @click="batchTagMode = 'remove'"
            >
              <Trash2 :size="16" />
              <span>删除标签</span>
            </button>
          </div>

          <p class="modal-desc">
            {{ batchTagMode === 'add' ? '为' : '从' }}选中的 <strong>{{ selectedPrompts.size }}</strong> 个提示词{{ batchTagMode === 'add' ? '添加' : '移除' }}标签：
          </p>

          <div v-if="loadingTags" class="loading-state">
            <span>加载标签中...</span>
          </div>

          <div v-else-if="userTags.length === 0" class="empty-state">
            <span>暂无个人标签，请先创建标签</span>
          </div>

          <div v-else class="tags-list">
            <label
              v-for="tag in userTags"
              :key="tag.id"
              class="tag-radio"
              :class="{ 'remove-mode': batchTagMode === 'remove' }"
            >
              <input
                type="radio"
                :value="tag.id"
                v-model="batchTagSelected"
              />
              <span class="tag-name">{{ tag.tag_name }}</span>
            </label>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="cancelBatchTag">取消</button>
          <button
            v-if="batchTagMode === 'add'"
            class="btn-primary"
            @click="executeBatchAddTag"
            :disabled="!batchTagSelected || loadingTags"
          >
            确认添加
          </button>
          <button
            v-else
            class="btn-danger"
            @click="executeBatchRemoveTag"
            :disabled="!batchTagSelected || loadingTags"
          >
            确认删除
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.view-wrapper {
  display: flex;
  height: 100%;
  width: 100%;
}

.content-body {
    flex: 1;
    overflow-y: auto;
    padding: 0 var(--layout-gap) var(--layout-gap) var(--layout-gap);
    min-width: 0; /* Prevent flex overflow */
}

.content-container {
    max-width: 1200px;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: 16px;
}

.sticky-header {
    position: sticky;
    top: 0;
    z-index: 100;
    background: var(--bg-primary);
    padding-top: 16px;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--border-subtle);
    display: flex;
    flex-direction: column;
    gap: 16px;
}

/* Toolbar */
.toolbar {
  padding: 16px;
  border-radius: var(--radius-xl);
  display: flex;
  flex-direction: column;
  gap: 16px;
  background: var(--bg-surface);
  border: 1px solid rgba(0,0,0,0.02);
  box-shadow: var(--shadow-sm);
}

.search-section {
  width: 100%;
}

.search-input-wrapper {
  position: relative;
  display: flex;
  align-items: center;
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 16px;
  color: var(--text-tertiary);
  pointer-events: none;
}

.main-search-input {
  width: 100%;
  height: 48px;
  padding: 0 48px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  font-size: 16px;
  color: var(--text-primary);
  background: var(--bg-primary);
  transition: all 0.2s;
}

.main-search-input:focus {
  outline: none;
  border-color: var(--primary);
  box-shadow: 0 0 0 3px var(--primary-light);
}

.search-shortcut {
  position: absolute;
  right: 16px;
  display: flex;
  align-items: center;
  gap: 4px;
  color: var(--text-tertiary);
  font-size: 12px;
  pointer-events: none;
}

.search-shortcut kbd {
  background: var(--bg-tertiary);
  border: 1px solid var(--border-subtle);
  border-radius: 4px;
  padding: 2px 6px;
  font-family: inherit;
  min-width: 20px;
  text-align: center;
}

.filter-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
}

.filter-tabs {
  display: flex;
  gap: 8px;
  padding: 4px;
  background: var(--bg-tertiary);
  border-radius: var(--radius-lg);
}

.filter-tab {
  padding: 6px 16px;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
  background: transparent;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  white-space: nowrap;
}

.filter-tab:hover {
  color: var(--text-primary);
}

.filter-tab.active {
  background: var(--bg-primary);
  color: var(--text-primary);
  box-shadow: var(--shadow-sm);
}

.sort-selector {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-label {
  font-size: 14px;
  color: var(--text-secondary);
}

.select-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.sort-select {
  appearance: none;
  padding: 6px 32px 6px 12px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  font-size: 14px;
  color: var(--text-primary);
  background: var(--bg-primary);
  cursor: pointer;
  transition: all 0.2s;
}

.sort-select:hover {
  border-color: var(--text-secondary);
}

.sort-select:focus {
  outline: none;
  border-color: var(--primary);
}

.select-icon {
  position: absolute;
  right: 8px;
  color: var(--text-tertiary);
  pointer-events: none;
}

.page-header {
    padding-top: var(--layout-gap);
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
}

.header-content {
    flex: 1;
    min-width: 300px;
}

.page-title {
    font-size: 24px;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 4px;
}

.page-desc {
    color: var(--text-secondary);
    font-size: 14px;
}

.header-actions {
    display: flex;
    gap: 8px;
    flex-shrink: 0;
    align-items: center;
}

.tools-section {
    margin-top: 6px;
}

.btn-primary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: var(--primary);
    color: white;
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: none;
}

.btn-primary:hover {
    background: var(--primary-hover);
}

.btn-primary:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.btn-secondary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: var(--bg-secondary);
    color: var(--text-primary);
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: 1px solid var(--border-subtle);
}

.btn-secondary:hover {
    background: var(--bg-tertiary);
}

.btn-secondary:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.btn-danger {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: #ef4444;
    color: white;
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: none;
}

.btn-danger:hover:not(:disabled) {
    background: #dc2626;
}

.btn-danger:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.selected-count {
    font-size: 14px;
    color: var(--text-secondary);
    padding: 0 8px;
}

.list-container {
    flex: 1;
    min-height: 0;
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
    min-width: 400px;
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

.primary-icon {
    color: var(--primary);
}

.modal-body {
    margin-bottom: 24px;
}

.modal-body p {
    margin-bottom: 8px;
    color: var(--text-primary);
}

.modal-body .text-secondary {
    color: var(--text-secondary);
    font-size: 14px;
}

.checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 16px;
    cursor: pointer;
    font-size: 14px;
    color: var(--text-secondary);
}

.checkbox-label input[type="checkbox"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
}

.modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
}

/* Batch Tag Modal Styles */
.batch-tag-modal {
    max-width: 480px;
    width: 90vw;
}

.mode-tabs {
    display: flex;
    gap: 8px;
    margin-bottom: 16px;
    padding: 4px;
    background: var(--bg-secondary);
    border-radius: 10px;
}

.mode-tab {
    flex: 1;
    display: flex;
    align-items: center;
    justify-content: center;
    gap: 6px;
    padding: 10px 16px;
    border: none;
    border-radius: 8px;
    background: transparent;
    color: var(--text-secondary);
    font-size: 14px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
}

.mode-tab:hover {
    color: var(--text-primary);
}

.mode-tab.active {
    background: var(--bg-surface);
    color: var(--primary);
    box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.mode-tab.active.remove-mode {
    color: #ef4444;
}

.modal-desc {
    margin-bottom: 16px;
    font-size: 14px;
    color: var(--text-primary);
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
    max-height: 300px;
    overflow-y: auto;
    padding: 4px;
}

.tag-radio {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 12px 16px;
    border-radius: 8px;
    border: 1px solid var(--border-subtle);
    cursor: pointer;
    transition: all 0.2s;
}

.tag-radio:hover {
    background: var(--bg-secondary);
    border-color: var(--primary);
}

.tag-radio.remove-mode:hover {
    border-color: #ef4444;
    background: #fef2f2;
}

.tag-radio input[type="radio"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
}

.tag-radio .tag-name {
    font-size: 14px;
    color: var(--text-primary);
}

@media (max-width: 768px) {
    .main-content {
        margin-left: var(--sidebar-width-collapsed);
    }
    
    .view-wrapper {
        flex-direction: column;
    }
    
    .header-actions {
        flex-wrap: wrap;
        gap: 8px;
    }
    
    .modal-content {
        min-width: auto;
        margin: 16px;
    }
}
</style>

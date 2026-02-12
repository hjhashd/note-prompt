<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch, inject, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ArrowUpDown, Box, Heart, Eye, User, ThumbsUp, Maximize2, CheckSquare, Square } from 'lucide-vue-next'
import * as LucideIcons from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'
import PromptDetailModal from '@/components/common/PromptDetailModal.vue'
import PromptSkeleton from '@/components/ui/Skeleton/PromptSkeleton.vue'
import { getPrompts, toggleFavorite, toggleLike, getPromptDetail } from '@/api/prompt'
import { deletePrompt } from '@/api/promptSave'
import { useToast } from '@/composables/useToast'
import type { PromptItem } from '@/types/prompt'

const router = useRouter()
const { toast } = useToast()
const searchQuery = ref('')
const activeFilter = ref('all')
const sortBy = ref('updatedAt')
const searchInputRef = ref<HTMLInputElement | null>(null)
const prompts = ref<PromptItem[]>([])
const loading = ref(false)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(12)
const showDetailModal = ref(false)
const selectedPromptId = ref<number | null>(null)
const selectedPromptData = ref<PromptItem | null>(null)

const props = defineProps<{
  isSidebarCollapsed?: boolean
  tagId?: number | null
  deptId?: number | null
  filter?: string
  sort?: string
  search?: string
  hideToolbar?: boolean
}>()

const emit = defineEmits<{
  (e: 'promptsDeleted', promptIds: number[]): void
}>()

// 注入删除模式状态
const isDeleteMode = inject<Ref<boolean>>('isDeleteMode', ref(false))
const selectedPrompts = inject<Ref<Set<number>>>('selectedPrompts', ref(new Set()))
const togglePromptSelection = inject<(promptId: number) => void>('togglePromptSelection', () => {})

// 暴露方法给父组件
const deleteSelectedPrompts = async (deleteWithSession = false): Promise<number[]> => {
  const idsToDelete = Array.from(selectedPrompts.value)
  if (idsToDelete.length === 0) return []
  
  const deletedIds: number[] = []
  
  for (const promptId of idsToDelete) {
    try {
      await deletePrompt(promptId, deleteWithSession)
      deletedIds.push(promptId)
    } catch (error: any) {
      console.error(`Failed to delete prompt ${promptId}:`, error)
    }
  }
  
  // 从列表中移除已删除的
  prompts.value = prompts.value.filter(p => !deletedIds.includes(p.id))
  total.value -= deletedIds.length
  
  // 清空选择
  selectedPrompts.value.clear()
  
  if (deletedIds.length > 0) {
    toast(`成功删除 ${deletedIds.length} 个提示词`, 'success')
    emit('promptsDeleted', deletedIds)
  }
  
  return deletedIds
}

defineExpose({
  deleteSelectedPrompts
})

const filters = [
  { id: 'all', label: '全部' },
  { id: 'my', label: '我创建的' },
  { id: 'favorites', label: '我的收藏' },
  { id: 'shared', label: '公共分享' }
]

const sortOptions = [
  { value: 'updatedAt', label: '最近更新' },
  { value: 'createdAt', label: '创建时间' },
  { value: 'views', label: '最多浏览' },
  { value: 'likes', label: '最多收藏' }
]

const formatTimeAgo = (dateStr: string) => {
  const date = new Date(dateStr)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)
  
  if (diffInSeconds < 60) return '刚刚'
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}分钟前`
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}小时前`
  if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}天前`
  return date.toLocaleDateString()
}

const loadMoreTrigger = ref<HTMLElement | null>(null)
let observer: IntersectionObserver | null = null

const fetchPromptsList = async (append = false) => {
  if (loading.value) return
  loading.value = true
  
  try {
    const res = await getPrompts({
      page: currentPage.value,
      pageSize: pageSize.value,
      keyword: props.search !== undefined ? props.search : searchQuery.value,
      filter: (props.filter || activeFilter.value) as any,
      sort: (props.sort || sortBy.value) as any,
      order: 'desc',
      tagId: props.tagId,
      deptId: props.deptId
    })
    
    if (append) {
      prompts.value = [...prompts.value, ...res.list]
    } else {
      prompts.value = res.list
    }
    total.value = res.total
  } catch (error) {
    console.error('Failed to fetch prompts:', error)
  } finally {
    loading.value = false
  }
}

// Watchers for refetching
watch([activeFilter, sortBy], () => {
  // If external control is enabled (props provided), ignore internal changes
  if (props.filter || props.sort) return

  currentPage.value = 1
  prompts.value = [] 
  fetchPromptsList(false)
})

watch(() => [props.tagId, props.deptId, props.filter, props.sort, props.search], () => {
  currentPage.value = 1
  prompts.value = []
  fetchPromptsList(false)
})

let searchTimeout: ReturnType<typeof setTimeout>
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    prompts.value = []
    fetchPromptsList(false)
  }, 300)
})

const setupObserver = () => {
  observer = new IntersectionObserver((entries) => {
    const entry = entries[0]
    if (entry && entry.isIntersecting && !loading.value && prompts.value.length < total.value) {
      currentPage.value++
      fetchPromptsList(true)
    }
  }, {
    rootMargin: '200px', // 提前 200px 加载
    threshold: 0.1
  })

  if (loadMoreTrigger.value) {
    observer.observe(loadMoreTrigger.value)
  }
}

watch(loadMoreTrigger, (el) => {
  if (el && observer) {
    observer.disconnect()
    observer.observe(el)
  }
})

const getTagTone = (tag: string) => {
  const t = tag.toLowerCase()

  const tech = ['python', 'vue', 'typescript', 'sql', 'pandas', 'web', '前端', '后端', '数据库', '数据', '开发']
  const writing = ['写作', '文案', '周报', '办公', '邮件', '报告', '效率']
  const creative = ['ai绘画', 'midjourney', '设计', '创意', '故事', '绘画']
  const business = ['商业', '运营', '营销', '产品', '增长']

  if (tech.some((k) => t.includes(k))) return 'tag--blue'
  if (writing.some((k) => t.includes(k))) return 'tag--purple'
  if (creative.some((k) => t.includes(k))) return 'tag--amber'
  if (business.some((k) => t.includes(k))) return 'tag--emerald'
  return 'tag--gray'
}

const getPromptEmoji = (tags: string[]) => {
  const joined = tags.join(' ').toLowerCase()
  if (joined.includes('python')) return '🐍'
  if (joined.includes('vue')) return '🟢'
  if (joined.includes('sql')) return '🗄️'
  if (joined.includes('数据') || joined.includes('pandas')) return '📊'
  if (joined.includes('写作') || joined.includes('周报') || joined.includes('文案')) return '✍️'
  if (joined.includes('ai绘画') || joined.includes('midjourney') || joined.includes('设计')) return '🎨'
  return '✨'
}

const getIconComponent = (iconName: string) => {
  if (!iconName) return LucideIcons.Sparkles
  return (LucideIcons as any)[iconName] || LucideIcons.Sparkles
}

const handleCardClick = (prompt: PromptItem) => {
  // 删除模式下点击卡片切换选择状态
  if (isDeleteMode.value) {
    togglePromptSelection(prompt.id)
    return
  }
  
  router.push({
    path: '/studio',
    query: {
      promptId: prompt.id
    }
  })
}

const openDetailModal = (prompt: PromptItem) => {
  selectedPromptId.value = prompt.id
  selectedPromptData.value = prompt
  showDetailModal.value = true
}

const handleToggleFavorite = async (prompt: PromptItem) => {
  const newStatus = !prompt.isFavorited
  // Optimistic update
  prompt.isFavorited = newStatus
  prompt.stats.favorites = (prompt.stats.favorites || 0) + (newStatus ? 1 : -1)
  
  try {
    await toggleFavorite(prompt.id)
  } catch (error) {
    // Revert on error
    prompt.isFavorited = !newStatus
    prompt.stats.favorites = (prompt.stats.favorites || 0) + (!newStatus ? 1 : -1)
    console.error('Failed to toggle favorite:', error)
  }
}

const handleToggleLike = async (prompt: PromptItem) => {
  const newStatus = !prompt.isLiked
  // Optimistic update
  prompt.isLiked = newStatus
  prompt.stats.likes = (prompt.stats.likes || 0) + (newStatus ? 1 : -1)
  
  try {
    await toggleLike(prompt.id)
  } catch (error) {
    // Revert on error
    prompt.isLiked = !newStatus
    prompt.stats.likes = (prompt.stats.likes || 0) + (!newStatus ? 1 : -1)
    console.error('Failed to toggle like:', error)
  }
}

const handlePromptUpdate = (updatedPrompt: PromptItem) => {
  const index = prompts.value.findIndex(p => p.id === updatedPrompt.id)
  if (index !== -1) {
    prompts.value[index] = updatedPrompt
  }
}

const onGlobalKeydown = (e: KeyboardEvent) => {
  const key = e.key.toLowerCase()
  const isK = key === 'k'
  const modifierPressed = e.ctrlKey || e.metaKey
  if (!modifierPressed || !isK) return

  e.preventDefault()
  searchInputRef.value?.focus()
}

onMounted(() => {
  window.addEventListener('keydown', onGlobalKeydown)
  fetchPromptsList(false)
  setupObserver()
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onGlobalKeydown)
  if (observer) {
    observer.disconnect()
  }
})
</script>

<template>
  <div class="prompt-list-container">
    <!-- Toolbar -->
    <div class="toolbar" v-if="!hideToolbar">
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
            <select v-model="sortBy" class="sort-select">
              <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                {{ opt.label }}
              </option>
            </select>
            <ArrowUpDown class="select-icon" :size="14" />
          </div>
        </div>
      </div>
    </div>

    <!-- Stats Bar -->
    <div class="stats-bar">
      <div class="stat-item">
        <Box :size="16" />
        <span>共 {{ total }} 个提示词</span>
      </div>
    </div>

    <!-- Grid -->
    <div v-if="loading && prompts.length === 0" class="prompt-grid">
      <PromptSkeleton v-for="i in 8" :key="i" />
    </div>
    <div v-else-if="prompts.length" class="prompt-grid" :class="{ 'sidebar-collapsed': isSidebarCollapsed, 'delete-mode': isDeleteMode }">
      <div 
        v-for="prompt in prompts" 
        :key="prompt.id" 
        class="prompt-card" 
        :class="{ 
          'selected': selectedPrompts.has(prompt.id),
          'delete-mode': isDeleteMode 
        }"
      >
        <!-- 删除模式选择框 -->
        <div v-if="isDeleteMode" class="selection-indicator">
          <CheckSquare v-if="selectedPrompts.has(prompt.id)" :size="24" class="checked" />
          <Square v-else :size="24" class="unchecked" />
        </div>
        <div class="card-header">
          <div class="header-top">
            <div class="prompt-tags">
              <span
                v-for="tag in prompt.tags.slice(0, 2)"
                :key="tag"
                class="tag"
                :class="getTagTone(tag)"
              >
                {{ tag }}
              </span>
            </div>
            <div class="actions">
              <button class="like-btn" title="查看详情" @click.stop="openDetailModal(prompt)">
                <Eye :size="18" />
              </button>
              <CopyButton :text="prompt.content || ''" />
              <button v-if="filter !== 'my'" class="like-btn" :class="{ 'liked': prompt.isLiked }" @click.stop="handleToggleLike(prompt)">
                <ThumbsUp :size="18" :fill="prompt.isLiked ? 'currentColor' : 'none'" />
              </button>
              <button class="like-btn" :class="{ 'favorited': prompt.isFavorited }" @click.stop="handleToggleFavorite(prompt)">
                <Heart :size="18" :fill="prompt.isFavorited ? 'currentColor' : 'none'" />
              </button>
            </div>
          </div>
          <h3 class="prompt-title">
            <span class="title-icon" aria-hidden="true" :style="{ color: prompt.mainTag?.color || 'inherit' }">
              <component 
                v-if="prompt.mainTag?.icon" 
                :is="getIconComponent(prompt.mainTag.icon)" 
                :size="20"
                class="lucide-icon"
              />
              <span v-else>{{ getPromptEmoji(prompt.tags) }}</span>
            </span>
            <span class="title-text">{{ prompt.title }}</span>
          </h3>
        </div>
        
        <div class="card-body" @click="handleCardClick(prompt)">
          <p class="prompt-desc">{{ prompt.description || (prompt.content ? prompt.content.slice(0, 100) + (prompt.content.length > 100 ? '...' : '') : '暂无描述') }}</p>
          <div class="card-tags">
            <span 
              v-for="tag in (prompt.tags || []).slice(0, 2)" 
              :key="tag" 
              class="tag"
              :class="getTagTone(tag)"
            >
              {{ tag }}
            </span>
          </div>
        </div>
        
        <div class="card-footer">
          <div class="author-info">
            <span class="author-avatar">
              <!-- <img v-if="prompt.author.avatar" :src="prompt.author.avatar" alt="" class="avatar-img"> -->
              <template v-if="true">
                {{ prompt.author.name?.charAt(0).toUpperCase() || 'U' }}
              </template>
            </span>
            <span class="author-name">{{ prompt.author.name }}</span>
            <span class="divider">•</span>
            <span class="prompt-date">{{ formatTimeAgo(prompt.updatedAt) }}</span>
          </div>
          
          <div class="metrics">
            <div class="metric" title="浏览量">
              <Eye :size="14" />
              <span>{{ prompt.stats.views }}</span>
            </div>
            <div class="metric" title="点赞数">
              <ThumbsUp :size="14" />
              <span>{{ prompt.stats.likes || 0 }}</span>
            </div>
            <div class="metric" title="收藏数">
              <Heart :size="14" />
              <span>{{ prompt.stats.favorites || 0 }}</span>
            </div>
          </div>
        </div>

        <div class="card-overlay">
          <button class="use-btn">立即使用</button>
        </div>
      </div>
    </div>

    <div v-else-if="!loading" class="empty-state">
      <div class="empty-icon">
        <Search :size="34" />
      </div>
      <div class="empty-title">没有找到匹配的提示词</div>
      <div class="empty-desc">试试换个关键词，或清空搜索条件</div>
    </div>
    
    <div ref="loadMoreTrigger" class="loading-state" v-show="prompts.length > 0 || loading">
      <div v-if="loading" class="loading-spinner">加载中...</div>
      <div v-else-if="prompts.length >= total" class="no-more-data">已经到底啦</div>
      <div v-else class="trigger-area" style="height: 20px; width: 100%;"></div>
    </div>

    <PromptDetailModal 
      v-model:visible="showDetailModal" 
      :prompt-id="selectedPromptId"
      :initial-data="selectedPromptData" 
      @update="handlePromptUpdate"
    />
  </div>
</template>

<style scoped>
.prompt-list-container {
  display: flex;
  flex-direction: column;
  gap: 24px;
  padding-bottom: 40px; /* 底部留白 */
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
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 16px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-tertiary);
}

.main-search-input {
  width: 100%;
  padding: 12px 88px 12px 48px;
  border: none;
  border-radius: 24px; /* Pill Shape */
  font-size: 15px;
  background: var(--bg-secondary);
  color: var(--text-primary);
  transition: all var(--transition-fast);
}

.main-search-input:focus {
  outline: none;
  background: var(--bg-primary);
}

.search-shortcut {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-tertiary);
  font-size: 12px;
  pointer-events: none;
}

.search-shortcut kbd {
  font: inherit;
  padding: 2px 8px;
  border-radius: 8px;
  border: 1px solid rgba(0,0,0,0.05);
  background: var(--bg-surface);
  box-shadow: 0 1px 0 rgba(0,0,0,0.05);
}

.kbd-plus {
  opacity: 0.7;
}

@media (max-width: 768px) {
  .search-shortcut {
    display: none;
  }

  .main-search-input {
    padding-right: 16px;
  }
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
  background: var(--bg-secondary);
  padding: 4px;
  border-radius: 24px;
  gap: 4px;
}

.filter-tab {
  padding: 6px 16px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-weight: 500;
  font-size: 14px;
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.filter-tab:hover {
  color: var(--text-primary);
  background: rgba(0,0,0,0.03);
}

.filter-tab.active {
  background: var(--bg-surface);
  color: var(--primary);
  box-shadow: var(--shadow-sm);
  font-weight: 600;
}

.sort-selector {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-label {
  font-size: 13px;
  color: var(--text-secondary);
}

.select-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.sort-select {
  border: none;
  border-radius: 20px;
  padding: 6px 32px 6px 12px;
  font-size: 13px;
  color: var(--text-primary);
  background: var(--bg-secondary);
  cursor: pointer;
  appearance: none;
  transition: all var(--transition-fast);
}

.sort-select:hover {
  background: rgba(0,0,0,0.05);
}

.select-icon {
  position: absolute;
  right: 10px;
  color: var(--text-tertiary);
  pointer-events: none;
}

.sort-select:focus {
  outline: none;
  background: var(--bg-primary);
}

/* Stats */
.stats-bar {
  display: flex;
  padding: 0 8px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
  font-size: 13px;
}

/* Grid */
.prompt-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: var(--layout-gap);
}

.prompt-card {
  border-radius: var(--radius-xl);
  padding: 24px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-normal);
  position: relative;
  overflow: hidden;
  height: 240px;
  border: 1px solid rgba(0,0,0,0.02);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  cursor: pointer;
}

.prompt-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-card);
}

/* Delete Mode Styles */
.prompt-grid.delete-mode .prompt-card {
  position: relative;
  cursor: pointer;
}

.prompt-card.delete-mode {
  border: 2px solid transparent;
  transition: all 0.2s;
}

.prompt-card.delete-mode:hover {
  border-color: var(--primary);
}

.prompt-card.delete-mode.selected {
  border-color: var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
}

.selection-indicator {
  position: absolute;
  top: 12px;
  right: 12px;
  z-index: 10;
  pointer-events: none;
}

.selection-indicator .checked {
  color: var(--primary);
}

.selection-indicator .unchecked {
  color: var(--text-tertiary);
  opacity: 0.5;
}

.card-header {
  margin-bottom: 12px;
}

.header-top {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.actions {
  display: flex;
  gap: 8px;
}

.like-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-tertiary);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.like-btn:hover {
  background: rgba(0,0,0,0.05);
  color: #ef4444;
}

.like-btn.liked {
  color: #f59e0b;
}

.like-btn.favorited {
  color: #ef4444;
}

.card-body {
  flex: 1;
  margin-bottom: 16px;
  cursor: pointer;
}

.prompt-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 0;
  line-height: 1.4;
  display: flex;
  align-items: center;
  gap: 8px;
}

.title-icon {
  width: 20px;
  height: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}

.title-text {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.prompt-desc {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin-top: 8px;
}

.prompt-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.tag {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 100px;
  font-weight: 500;
}

.tag--blue {
  color: #1a73e8;
  background: #e8f0fe;
}

.tag--purple {
  color: #7030a0;
  background: #f3e5f5;
}

.tag--amber {
  color: #e67c73;
  background: #feefe3;
}

.tag--emerald {
  color: #0f9d58;
  background: #e6f4ea;
}

.tag--gray {
  color: var(--text-secondary);
  background: var(--bg-secondary);
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--bg-primary);
  font-size: 12px;
  color: var(--text-tertiary);
}

.author-info {
  display: flex;
  align-items: center;
  gap: 6px;
}

.author-avatar {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 10px;
  font-weight: 600;
  overflow: hidden;
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.divider {
  color: var(--bg-primary);
}

.metrics {
  display: flex;
  gap: 12px;
}

.metric {
  display: flex;
  align-items: center;
  gap: 4px;
}

/* Overlay Action */
.card-overlay {
  display: none;
}

.use-btn {
  background: var(--primary-600);
  color: white;
  border: none;
  padding: 8px 20px;
  border-radius: 100px;
  font-weight: 600;
  font-size: 14px;
  transform: translateY(10px);
  transition: all var(--transition-normal);
  box-shadow: var(--shadow-lg);
  cursor: pointer;
  pointer-events: auto;
}

/* Empty */
.empty-state {
  border-radius: var(--radius-xl);
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  padding: 44px 20px;
  text-align: center;
}

.empty-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 12px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--gray-500);
  background: var(--gray-50);
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.empty-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--gray-800);
}

.empty-desc {
  margin-top: 6px;
  font-size: 13px;
  color: var(--gray-500);
}

@keyframes fadeUp {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 50%;
}

.liked {
  color: #ef4444;
  background: #fef2f2;
  border-color: #fee2e2;
}

.loading-state {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 40px;
  color: var(--gray-500);
  font-size: 14px;
}
</style>

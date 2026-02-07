<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue'
import { Search, ArrowUpDown, Box, Heart, Eye, User } from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'
import PromptDetailModal from '@/components/common/PromptDetailModal.vue'
import { getPrompts, toggleFavorite, getPromptDetail } from '@/api/prompt'
import type { PromptItem } from '@/types/prompt'

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
const promptCache = new Map<number, PromptItem>()

const props = defineProps<{
  isSidebarCollapsed?: boolean
  tagId?: number | null
}>()

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
      keyword: searchQuery.value,
      filter: activeFilter.value as any,
      sort: sortBy.value as any,
      order: 'desc',
      tagId: props.tagId
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
  currentPage.value = 1
  // 切换筛选/排序时，清空列表并重新加载，防止滚动位置导致立即触发加载更多
  prompts.value = [] 
  fetchPromptsList(false)
})

watch(() => props.tagId, (newId) => {
  currentPage.value = 1
  prompts.value = []
  // When selecting a tag, we might want to reset filter to 'all' or keep it?
  // Usually 'all' makes sense unless user wants "My prompts in Python".
  // Let's keep the filter but reset page.
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

const handleCardClick = (prompt: PromptItem) => {
  selectedPromptId.value = prompt.id
  // Prefer cached full detail, fallback to list item summary
  selectedPromptData.value = promptCache.get(prompt.id) || prompt
  showDetailModal.value = true
}

const handleCardHover = async (prompt: PromptItem) => {
  if (promptCache.has(prompt.id)) return
  try {
     const detail = await getPromptDetail(prompt.id)
     promptCache.set(prompt.id, detail)
  } catch (e) {
     // silent error
  }
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
    <div v-if="prompts.length" class="prompt-grid" :class="{ 'sidebar-collapsed': isSidebarCollapsed }">
      <div 
        v-for="prompt in prompts" 
        :key="prompt.id" 
        class="prompt-card" 
        @click="handleCardClick(prompt)"
        @mouseenter="handleCardHover(prompt)"
      >
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
              <CopyButton :text="prompt.content || ''" />
              <button class="like-btn" :class="{ 'liked': prompt.isFavorited }" @click.stop="handleToggleFavorite(prompt)">
                <Heart :size="18" :fill="prompt.isFavorited ? 'currentColor' : 'none'" />
              </button>
            </div>
          </div>
          <h3 class="prompt-title">
            <span class="title-icon" aria-hidden="true">{{ getPromptEmoji(prompt.tags) }}</span>
            <span class="title-text">{{ prompt.title }}</span>
          </h3>
        </div>
        
        <div class="card-body">
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
              <img v-if="prompt.author.avatar" :src="prompt.author.avatar" alt="" class="avatar-img">
              <User v-else :size="12" />
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
  padding: 20px;
  border-radius: var(--radius-xl);
  display: flex;
  flex-direction: column;
  gap: 20px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
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
  color: var(--gray-400);
}

.main-search-input {
  width: 100%;
  padding: 14px 88px 14px 48px;
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-lg);
  font-size: 16px;
  background: var(--bg-surface);
  transition: all var(--transition-fast);
  box-shadow: var(--shadow-sm);
}

.main-search-input:focus {
  outline: none;
  border-color: var(--primary-300);
  box-shadow: 0 0 0 4px var(--primary-50);
}

.search-shortcut {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--gray-400);
  font-size: 12px;
  pointer-events: none;
}

.search-shortcut kbd {
  font: inherit;
  padding: 2px 8px;
  border-radius: 8px;
  border: 1px solid rgba(15, 23, 42, 0.10);
  background: rgba(255, 255, 255, 0.75);
  box-shadow: 0 1px 0 rgba(15, 23, 42, 0.08);
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
  background: var(--gray-100);
  padding: 4px;
  border-radius: var(--radius-lg);
  gap: 4px;
}

.filter-tab {
  padding: 8px 16px;
  border: none;
  background: transparent;
  color: var(--gray-600);
  font-weight: 500;
  font-size: 14px;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.filter-tab:hover {
  color: var(--gray-900);
}

.filter-tab.active {
  background: var(--bg-surface);
  color: var(--primary-600);
  box-shadow: var(--shadow-sm);
  font-weight: 600;
}

.sort-selector {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-label {
  font-size: 14px;
  color: var(--gray-500);
}

.select-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.sort-select {
  border: 1px solid var(--gray-200);
  border-radius: var(--radius-md);
  padding: 6px 32px 6px 12px;
  font-size: 14px;
  color: var(--gray-700);
  background: white;
  cursor: pointer;
  appearance: none;
}

.select-icon {
  position: absolute;
  right: 10px;
  color: var(--gray-400);
  pointer-events: none;
}

.sort-select:focus {
  outline: none;
  border-color: var(--primary-300);
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
  color: var(--gray-500);
  font-size: 14px;
}

/* Grid */
.prompt-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr); /* 默认显示3张卡片 */
  gap: 24px;
}

/* 当侧边栏收起时，展示更多，视空间决定 */
.prompt-grid.sidebar-collapsed {
  grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
}

@media (max-width: 1280px) {
  .prompt-grid {
    grid-template-columns: repeat(2, 1fr);
  }
  
  /* 在较小屏幕上，即使侧边栏收起也保持响应式 */
  .prompt-grid.sidebar-collapsed {
    grid-template-columns: repeat(auto-fill, minmax(240px, 1fr));
  }
}

@media (max-width: 768px) {
  .prompt-grid {
    grid-template-columns: 1fr;
  }
}

.prompt-card {
  border-radius: var(--radius-xl);
  padding: 24px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-normal);
  position: relative;
  overflow: hidden;
  height: 220px; /* 固定高度，确保长方形比例 */
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  animation: fadeUp 260ms ease both;
  cursor: pointer;
}

.prompt-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-md);
  border-color: var(--primary-200);
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
  border-radius: var(--radius-md);
  border: 1px solid transparent;
  background: transparent;
  color: var(--gray-400);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.like-btn:hover {
  background: var(--gray-50);
  color: var(--danger);
}

.card-body {
  flex: 1;
  margin-bottom: 16px;
}

.prompt-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--gray-900);
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
  font-size: 13px;
  color: var(--gray-500);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 3;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.prompt-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.tag {
  font-size: 11px;
  color: var(--gray-700);
  background: var(--gray-100);
  padding: 2px 8px;
  border-radius: 100px;
  font-weight: 500;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.tag--blue {
  color: #1d4ed8;
  background: #eff6ff;
  border-color: rgba(29, 78, 216, 0.18);
}

.tag--purple {
  color: #6d28d9;
  background: #f5f3ff;
  border-color: rgba(109, 40, 217, 0.18);
}

.tag--amber {
  color: #b45309;
  background: #fffbeb;
  border-color: rgba(180, 83, 9, 0.18);
}

.tag--emerald {
  color: #047857;
  background: #ecfdf5;
  border-color: rgba(4, 120, 87, 0.18);
}

.tag--gray {
  color: var(--gray-600);
  background: var(--gray-100);
  border-color: rgba(15, 23, 42, 0.06);
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 12px;
  border-top: 1px solid var(--gray-100);
  font-size: 12px;
  color: var(--gray-400);
}

.author-info {
  display: flex;
  align-items: center;
  gap: 6px;
}

.author-avatar {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  background: var(--gray-100);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--gray-500);
}

.divider {
  color: var(--gray-200);
}

.metrics {
  display: flex;
  gap: 10px;
}

.metric {
  display: flex;
  align-items: center;
  gap: 4px;
}

/* Overlay Action */
.card-overlay {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  background: rgba(255, 255, 255, 0.1);
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition: all var(--transition-normal);
  pointer-events: none;
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

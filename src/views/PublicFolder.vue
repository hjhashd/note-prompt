<script setup lang="ts">
import { ref, watch, computed, onMounted, onActivated } from 'vue'
import { onBeforeRouteLeave } from 'vue-router'
import { useAppStore } from '@/stores/app'
import PromptCategorySidebar from '@/components/prompt/PromptCategorySidebar.vue'
import TiledCategoryFilter from '@/components/prompt/TiledCategoryFilter.vue'
import PromptList from '@/components/layout/PromptList.vue'
import { 
  Search, 
  Download
} from 'lucide-vue-next'

const appStore = useAppStore()
const searchQuery = ref('')
const activeTab = ref('latest')
const activeSort = ref('newest')
const contentBodyRef = ref<HTMLElement | null>(null)
const promptListRef = ref<InstanceType<typeof PromptList> | null>(null)
const scrollStorageKey = 'scroll:public-folder'

const restoreScroll = () => {
  const saved = sessionStorage.getItem(scrollStorageKey)
  if (!contentBodyRef.value || saved === null) return
  contentBodyRef.value.scrollTop = Number(saved)
}

const saveScroll = () => {
  if (!contentBodyRef.value) return
  sessionStorage.setItem(scrollStorageKey, String(contentBodyRef.value.scrollTop))
}

// Sidebar selection (Category/Department context)
const sidebarSelection = ref<number | null>(null)
// Tiled filter selection (Sub-category refinement)
const filterSelection = ref<number | number[] | null>(null)

// Reset filter when sidebar category changes
watch(sidebarSelection, () => {
  filterSelection.value = null
})

// Effective tag ID for data fetching (Refinement > Context)
const currentTagId = computed(() => filterSelection.value)

const toggleSidebar = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

// Sync tabs with sort options where applicable
watch(activeTab, (newTab) => {
  if (newTab === 'latest') {
    activeSort.value = 'newest'
  } else if (newTab === 'popular') {
    activeSort.value = 'popular'
  }
})

const tabs = [
  { id: 'latest', label: '最新' },
  { id: 'popular', label: '最热' }
]

const sortOptions = [
  { value: 'newest', label: '最新发布' },
  { value: 'popular', label: '最多使用' },
  { value: 'likes', label: '最多收藏' }
]

const sortMap: Record<string, string> = {
  'newest': 'createdAt',
  'popular': 'views',
  'likes': 'likes'
}

onMounted(restoreScroll)
onActivated(() => {
  restoreScroll()
})
onBeforeRouteLeave(() => {
  saveScroll()
})
</script>

<template>
  <div class="view-wrapper">
    <!-- Secondary Sidebar (Departments) -->
    <div class="secondary-sidebar-wrapper">
      <PromptCategorySidebar v-model="sidebarSelection" />
    </div>

    <div class="content-body" ref="contentBodyRef">
          <div class="content-container">
            <!-- Page Header -->
            <div class="page-header">
              <div class="header-content">
                <h1 class="page-title">提示词广场</h1>
                <p class="page-desc">探索社区精选的优质提示词，激发你的创作灵感。</p>
              </div>
            </div>

            <div class="sticky-header">
              <!-- Tiled Category Filter (Sub-tags of selected department) -->
              <TiledCategoryFilter 
                v-model="filterSelection" 
                :parent-id="sidebarSelection"
              />

              <!-- Filter & Search Bar -->
              <div class="filter-section">
                <div class="search-wrapper">
                  <Search class="search-icon" />
                  <input 
                    v-model="searchQuery" 
                    type="text" 
                    placeholder="搜索公共提示词..." 
                    class="search-input"
                  >
                </div>
                
                <div class="filter-controls">
                  <div class="tabs">
                    <button 
                      v-for="tab in tabs" 
                      :key="tab.id"
                      class="tab-btn"
                      :class="{ active: activeTab === tab.id }"
                      @click="activeTab = tab.id"
                    >
                      {{ tab.label }}
                    </button>
                  </div>
                  
                  <div class="divider"></div>
                  
                  <div class="sort-wrapper">
                    <span class="sort-label">排序:</span>
                    <select v-model="activeSort" class="sort-select">
                      <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                        {{ opt.label }}
                      </option>
                    </select>
                  </div>
                </div>
              </div>
            </div>

            <!-- Prompts List with Infinite Scroll -->
            <PromptList
              :is-sidebar-collapsed="appStore.isSidebarCollapsed"
              :dept-id="sidebarSelection"
              :tag-id="currentTagId"
              :search="searchQuery"
              :sort="sortMap[activeSort]"
              filter="plaza"
              :hide-toolbar="true"
              :show-quote-action="true"
              ref="promptListRef"
            />
          </div>
        </div>
      </div>
</template>

<style scoped>
/* App Layout styles moved to App.vue */

.view-wrapper {
  display: flex;
  height: 100%;
  width: 100%;
}

.secondary-sidebar-wrapper {
  height: 100%;
  padding: var(--layout-gap) 0 var(--layout-gap) var(--layout-gap);
  background: transparent;
  flex-shrink: 0;
}

.content-body {
  flex: 1;
  overflow-y: auto;
  /* Remove top padding to allow sticky header to reach the top edge without gaps */
  padding: 0 var(--layout-gap) var(--layout-gap) var(--layout-gap);
  min-width: 0;
}

.content-container {
  max-width: 1600px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 24px;
}

/* Page Header */
.sticky-header {
  position: sticky;
  top: 0;
  z-index: 100;
  background-color: var(--bg-primary, #fff);
  /* Extend background to cover horizontal gaps if any, but with container padding 0, this might not be needed for top gap */
  /* However, we need to handle horizontal padding of content-body if we want full width sticky */
  /* Since content-body has horizontal padding, sticky header is inside content-container */
  /* We want sticky header background to extend? No, it's inside container. */
  padding-top: 16px;
  padding-bottom: 24px;
  display: flex;
  flex-direction: column;
  gap: 16px;
}

.page-header {
  /* Add top padding to compensate for removed content-body padding */
  padding-top: var(--layout-gap);
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.page-title {
  font-size: 24px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 8px;
}

.page-desc {
  color: var(--text-secondary);
  font-size: 14px;
}

.primary-btn {
  display: flex;
  align-items: center;
  padding: 8px 16px;
  background-color: var(--primary);
  color: white;
  border-radius: 9999px;
  font-weight: 500;
  font-size: 14px;
  transition: all 0.2s;
}

.primary-btn:hover {
  background-color: var(--primary-hover);
  transform: translateY(-1px);
}

/* Filter Section */
.filter-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 16px;
  background: var(--bg-surface);
  padding: 16px;
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
}

.search-wrapper {
  position: relative;
  flex: 1;
  max-width: 400px;
}

.search-icon {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--text-secondary);
}

.search-input {
  width: 100%;
  padding: 10px 12px 10px 40px;
  border: 1px solid var(--border-color);
  border-radius: 9999px;
  background: var(--bg-secondary);
  font-size: 14px;
  transition: all 0.2s;
}

.search-input:focus {
  background: white;
  border-color: var(--primary);
  box-shadow: 0 0 0 2px var(--primary-light);
}

.filter-controls {
  display: flex;
  align-items: center;
  gap: 16px;
}

.tabs {
  display: flex;
  background: var(--bg-secondary);
  padding: 4px;
  border-radius: 8px;
}

.tab-btn {
  padding: 6px 16px;
  border-radius: 6px;
  font-size: 14px;
  color: var(--text-secondary);
  font-weight: 500;
  transition: all 0.2s;
}

.tab-btn:hover {
  color: var(--text-primary);
}

.tab-btn.active {
  background: white;
  color: var(--primary);
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

.divider {
  width: 1px;
  height: 24px;
  background: var(--border-color);
}

.sort-wrapper {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-label {
  font-size: 14px;
  color: var(--text-secondary);
}

.sort-select {
  padding: 6px 12px;
  border: 1px solid var(--border-color);
  border-radius: 6px;
  font-size: 14px;
  color: var(--text-primary);
  background: white;
  cursor: pointer;
}

/* Prompts Grid */
.prompts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
}

.loading-state, .empty-state {
  text-align: center;
  padding: 40px;
  color: var(--text-secondary);
  font-size: 14px;
}

.prompt-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid rgba(0,0,0,0.04);
  padding: 20px;
  transition: all 0.3s ease;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  height: 100%;
}

.prompt-card:hover {
  transform: translateY(-2px);
  box-shadow: var(--shadow-card);
  border-color: rgba(0,0,0,0.08);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 16px;
}

.prompt-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.action-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary);
  background: transparent;
  transition: all 0.2s;
  opacity: 0;
}

.group:hover .action-btn {
  opacity: 1;
}

.action-btn:hover {
  background: var(--bg-secondary);
  color: var(--primary);
}

.card-body {
  flex: 1;
  margin-bottom: 20px;
}

.prompt-meta {
  margin-bottom: 12px;
}

.category-tag {
  font-size: 12px;
  font-weight: 500;
  padding: 4px 10px;
  background: var(--bg-secondary);
  border-radius: 9999px;
  color: var(--text-secondary);
  text-transform: capitalize;
}

.prompt-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 8px;
  line-height: 1.4;
}

.prompt-desc {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--border-subtle);
}

.author-info {
  display: flex;
  align-items: center;
  gap: 8px;
}

.author-name {
  font-size: 13px;
  color: var(--text-secondary);
}

.stats {
  display: flex;
  gap: 12px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 12px;
  color: var(--text-secondary);
}

@media (max-width: 1024px) {
  .prompts-grid {
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  }
}

@media (max-width: 768px) {
  .main-content {
    margin-left: var(--sidebar-width-collapsed);
  }
  
  .view-wrapper {
    flex-direction: column;
  }
  
  .secondary-sidebar-wrapper {
    width: 100%;
    height: auto;
    border-right: none;
    border-bottom: 1px solid var(--border-subtle);
  }
  
  .filter-section {
    flex-direction: column;
    align-items: stretch;
  }
  
  .search-wrapper {
    max-width: none;
  }
  
  .filter-controls {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .tabs {
    width: 100%;
    overflow-x: auto;
  }
  
  .tab-btn {
    white-space: nowrap;
  }
}
</style>

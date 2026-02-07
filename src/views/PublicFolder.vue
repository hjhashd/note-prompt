<script setup lang="ts">
import { ref } from 'vue'
import Sidebar from '@/components/layout/Sidebar.vue'
import { 
  Search, 
  Heart, 
  Download, 
  Copy, 
  Zap, 
  Code, 
  PenTool, 
  MessageSquare 
} from 'lucide-vue-next'

const isSidebarCollapsed = ref(false)
const searchQuery = ref('')
const activeTab = ref('recommended')
const activeSort = ref('newest')

const toggleSidebar = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

// Mock Data for Public Prompts
const publicPrompts = ref([
  {
    id: 1,
    title: 'Vue 3 组合式 API 最佳实践',
    description: '一套完整的 Vue 3 Composition API 编码规范和最佳实践指南，包含状态管理、组件通信等核心概念的代码示例。',
    author: 'FrontendMaster',
    likes: 1240,
    downloads: 856,
    tags: ['Vue 3', 'TypeScript', 'Best Practices'],
    category: 'coding',
    icon: Code,
    color: 'blue'
  },
  {
    id: 2,
    title: 'SEO 优化文章生成器',
    description: '输入关键词，自动生成符合 SEO 规范的高质量博客文章结构，包含标题、Meta 描述和关键词布局建议。',
    author: 'ContentPro',
    likes: 892,
    downloads: 430,
    tags: ['Marketing', 'SEO', 'Writing'],
    category: 'writing',
    icon: PenTool,
    color: 'purple'
  },
  {
    id: 3,
    title: 'Midjourney 提示词生成助手',
    description: '帮助你构建高质量的 Midjourney 绘画提示词，包含光照、构图、风格等详细参数的调整建议。',
    author: 'AI_Artist',
    likes: 2150,
    downloads: 1800,
    tags: ['AI Art', 'Midjourney', 'Design'],
    category: 'design',
    icon: Zap,
    color: 'indigo'
  },
  {
    id: 4,
    title: '周报生成器',
    description: '根据你的一周工作内容要点，自动生成结构清晰、语气专业的周报内容，支持多种职场场景。',
    author: 'OfficeProductivity',
    likes: 670,
    downloads: 320,
    tags: ['Productivity', 'Business', 'Writing'],
    category: 'productivity',
    icon: MessageSquare,
    color: 'green'
  },
  {
    id: 5,
    title: 'Python 数据分析入门',
    description: '针对初学者的 Python 数据分析学习路径和常用代码片段，涵盖 Pandas、NumPy 的基础操作。',
    author: 'DataWizard',
    likes: 540,
    downloads: 210,
    tags: ['Python', 'Data Science', 'Education'],
    category: 'coding',
    icon: Code,
    color: 'orange'
  },
  {
    id: 6,
    title: 'React Hooks 深度解析',
    description: '深入探讨 React Hooks 的底层原理和高级用法，帮助开发者避免常见的闭包陷阱和性能问题。',
    author: 'ReactExpert',
    likes: 980,
    downloads: 650,
    tags: ['React', 'JavaScript', 'Advanced'],
    category: 'coding',
    icon: Code,
    color: 'cyan'
  }
])

const tabs = [
  { id: 'recommended', label: '推荐' },
  { id: 'latest', label: '最新' },
  { id: 'popular', label: '最热' },
  { id: 'official', label: '官方' }
]

const sortOptions = [
  { value: 'newest', label: '最新发布' },
  { value: 'popular', label: '最多使用' },
  { value: 'likes', label: '最多收藏' }
]

const getIconColor = (color: string) => {
  const colors: Record<string, string> = {
    blue: 'text-blue-600 bg-blue-50',
    purple: 'text-purple-600 bg-purple-50',
    indigo: 'text-indigo-600 bg-indigo-50',
    green: 'text-emerald-600 bg-emerald-50',
    orange: 'text-orange-600 bg-orange-50',
    cyan: 'text-cyan-600 bg-cyan-50'
  }
  return colors[color] || colors.blue
}
</script>

<template>
  <div class="app-layout">
    <Sidebar :collapsed="isSidebarCollapsed" @toggle="toggleSidebar" />

    <main class="main-content" :class="{ collapsed: isSidebarCollapsed }">
      <div class="content-body">
        <div class="content-container">
          <!-- Page Header -->
          <div class="page-header">
            <div class="header-content">
              <h1 class="page-title">公共文件夹</h1>
              <p class="page-desc">探索社区精选的优质提示词，激发你的创作灵感。</p>
            </div>
            <div class="header-actions">
              <button class="primary-btn">
                <Download class="w-4 h-4 mr-2" />
                导入提示词
              </button>
            </div>
          </div>

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

          <!-- Prompts Grid -->
          <div class="prompts-grid">
            <div v-for="prompt in publicPrompts" :key="prompt.id" class="prompt-card group">
              <div class="card-header">
                <div class="prompt-icon" :class="getIconColor(prompt.color)">
                  <component :is="prompt.icon" :size="24" stroke-width="1.5" />
                </div>
                <div class="card-actions">
                  <button class="action-btn" title="收藏">
                    <Heart :size="18" />
                  </button>
                  <button class="action-btn" title="复制">
                    <Copy :size="18" />
                  </button>
                </div>
              </div>
              
              <div class="card-body">
                <h3 class="card-title">{{ prompt.title }}</h3>
                <p class="card-desc">{{ prompt.description }}</p>
                
                <div class="card-tags">
                  <span v-for="tag in prompt.tags" :key="tag" class="tag">
                    {{ tag }}
                  </span>
                </div>
              </div>
              
              <div class="card-footer">
                <div class="author-info">
                  <div class="avatar-sm">{{ prompt.author.charAt(0) }}</div>
                  <span class="author-name">{{ prompt.author }}</span>
                </div>
                <div class="stats">
                  <span class="stat-item">
                    <Heart :size="14" class="mr-1" />
                    {{ prompt.likes }}
                  </span>
                  <span class="stat-item">
                    <Download :size="14" class="mr-1" />
                    {{ prompt.downloads }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  min-height: 100vh;
  background-color: var(--bg-primary);
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  transition: margin-left var(--transition-normal) cubic-bezier(0.4, 0, 0.2, 1);
  min-height: 100vh;
  display: flex;
  flex-direction: column;
  background: var(--bg-primary);
}

.main-content.collapsed {
  margin-left: var(--sidebar-width-collapsed);
}

.content-body {
  flex: 1;
  padding: 2rem;
  overflow-y: auto;
}

.content-container {
  max-width: 1200px;
  margin: 0 auto;
}

/* Page Header */
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 2rem;
}

.page-title {
  font-size: 1.875rem;
  font-weight: 600;
  color: var(--gray-900);
  margin-bottom: 0.5rem;
  letter-spacing: -0.025em;
}

.page-desc {
  color: var(--gray-500);
  font-size: 1rem;
  max-width: 600px;
}

.primary-btn {
  display: inline-flex;
  align-items: center;
  padding: 0.625rem 1.25rem;
  background-color: var(--primary-600);
  color: white;
  border-radius: 0.5rem;
  font-weight: 500;
  transition: all 0.2s;
  border: 1px solid transparent;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);
}

.primary-btn:hover {
  background-color: var(--primary-700);
  transform: translateY(-1px);
}

/* Filter Section */
.filter-section {
  background: var(--bg-surface);
  border-radius: 1rem;
  padding: 1.25rem;
  margin-bottom: 2rem;
  border: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  box-shadow: var(--shadow-sm);
}

.search-wrapper {
  position: relative;
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 1rem;
  top: 50%;
  transform: translateY(-50%);
  color: var(--gray-400);
  width: 1.25rem;
  height: 1.25rem;
}

.search-input {
  width: 100%;
  padding: 0.75rem 1rem 0.75rem 2.75rem;
  border: 1px solid var(--border-subtle);
  border-radius: 0.75rem;
  font-size: 0.95rem;
  transition: all 0.2s;
  background-color: var(--bg-primary);
}

.search-input:focus {
  background-color: var(--bg-surface);
  border-color: var(--primary-500);
  box-shadow: 0 0 0 3px var(--primary-100);
  outline: none;
}

.filter-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
}

.tabs {
  display: flex;
  background: var(--bg-primary);
  padding: 0.25rem;
  border-radius: 0.75rem;
}

.tab-btn {
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--gray-600);
  transition: all 0.2s;
}

.tab-btn:hover {
  color: var(--gray-900);
}

.tab-btn.active {
  background: var(--bg-surface);
  color: var(--primary-600);
  box-shadow: var(--shadow-sm);
}

.divider {
  width: 1px;
  height: 24px;
  background: var(--border-subtle);
  margin: 0 0.5rem;
}

.sort-wrapper {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.sort-label {
  font-size: 0.875rem;
  color: var(--gray-500);
}

.sort-select {
  padding: 0.5rem 2rem 0.5rem 0.75rem;
  border-radius: 0.5rem;
  border: 1px solid var(--border-subtle);
  background-color: var(--bg-surface);
  font-size: 0.875rem;
  color: var(--gray-700);
  cursor: pointer;
  appearance: none;
  background-image: url("data:image/svg+xml,%3csvg xmlns='http://www.w3.org/2000/svg' fill='none' viewBox='0 0 20 20'%3e%3cpath stroke='%236b7280' stroke-linecap='round' stroke-linejoin='round' stroke-width='1.5' d='M6 8l4 4 4-4'/%3e%3c/svg%3e");
  background-position: right 0.5rem center;
  background-repeat: no-repeat;
  background-size: 1.5em 1.5em;
}

/* Prompts Grid */
.prompts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 1.5rem;
}

.prompt-card {
  background: var(--bg-surface);
  border-radius: 1rem;
  border: 1px solid var(--border-subtle);
  padding: 1.5rem;
  transition: all 0.3s ease;
  display: flex;
  flex-direction: column;
  position: relative;
  cursor: pointer;
  box-shadow: var(--shadow-sm);
}

.prompt-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-md);
  border-color: var(--primary-200);
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 1rem;
}

.prompt-icon {
  width: 48px;
  height: 48px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: transform 0.3s ease;
}

.prompt-card:hover .prompt-icon {
  transform: scale(1.1) rotate(5deg);
}

.card-actions {
  display: flex;
  gap: 0.5rem;
  opacity: 0;
  transform: translateX(10px);
  transition: all 0.3s ease;
}

.prompt-card:hover .card-actions {
  opacity: 1;
  transform: translateX(0);
}

.action-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--gray-400);
  transition: all 0.2s;
  background: var(--bg-primary);
}

.action-btn:hover {
  background: var(--primary-50);
  color: var(--primary-600);
}

.card-body {
  flex: 1;
  margin-bottom: 1.5rem;
}

.card-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--gray-900);
  margin-bottom: 0.5rem;
  line-height: 1.4;
}

.card-desc {
  color: var(--gray-500);
  font-size: 0.875rem;
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin-bottom: 1rem;
}

.card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.tag {
  padding: 0.25rem 0.75rem;
  background: var(--bg-primary);
  color: var(--gray-600);
  border-radius: 1rem;
  font-size: 0.75rem;
  font-weight: 500;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 1rem;
  border-top: 1px solid var(--border-subtle);
}

.author-info {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.avatar-sm {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: linear-gradient(135deg, var(--primary-400), var(--primary-600));
  color: white;
  font-size: 0.75rem;
  font-weight: 600;
  display: flex;
  align-items: center;
  justify-content: center;
}

.author-name {
  font-size: 0.875rem;
  color: var(--gray-600);
  font-weight: 500;
}

.stats {
  display: flex;
  gap: 1rem;
}

.stat-item {
  display: flex;
  align-items: center;
  font-size: 0.75rem;
  color: var(--gray-500);
  font-weight: 500;
}

/* Responsive */
@media (max-width: 1024px) {
  .prompts-grid {
    grid-template-columns: repeat(2, 1fr);
  }
}

@media (max-width: 768px) {
  .main-content {
    margin-left: 0;
  }
  
  .content-body {
    padding: 1.5rem;
  }
  
  .filter-section {
    flex-direction: column;
    align-items: stretch;
  }
  
  .filter-controls {
    flex-direction: column;
    align-items: flex-start;
  }
  
  .tabs {
    width: 100%;
    justify-content: space-between;
  }
  
  .tab-btn {
    flex: 1;
    text-align: center;
  }
  
  .prompts-grid {
    grid-template-columns: 1fr;
  }
}
</style>
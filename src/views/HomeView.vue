<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { Plus } from 'lucide-vue-next'
import Sidebar from '@/components/layout/Sidebar.vue'
import TagDirectory from '@/components/layout/TagDirectory.vue'
import PromptList from '@/components/layout/PromptList.vue'

const router = useRouter()
const isSidebarCollapsed = ref(false)
const isDirectoryCollapsed = ref(false)
const currentTagId = ref<number | null>(null)

const toggleSidebar = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

const toggleDirectory = () => {
  isDirectoryCollapsed.value = !isDirectoryCollapsed.value
}

const createPrompt = () => {
  router.push('/studio')
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
              <h1 class="page-title">我的提示词</h1>
              <p class="page-desc">管理和组织你的个人提示词库，快速访问和复用</p>
            </div>
            <div class="header-actions">
              <button class="btn-primary" @click="createPrompt">
                <Plus :size="20" />
                <span>新建提示词</span>
              </button>
            </div>
          </div>

          <!-- Main Layout Grid -->
          <div class="main-grid" :class="{ 'directory-collapsed': isDirectoryCollapsed }">
            <div class="left-panel">
              <TagDirectory 
                :collapsed="isDirectoryCollapsed" 
                @toggleCollapse="toggleDirectory" 
                @select="id => currentTagId = id"
              />
            </div>
            <div class="right-panel">
              <PromptList 
                :is-sidebar-collapsed="isSidebarCollapsed" 
                :tag-id="currentTagId"
              />
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
    background-color: var(--bg-surface-soft);
}

.main-content {
    flex: 1;
    margin-left: var(--sidebar-width);
    min-width: 0;
    background: var(--bg-primary);
    height: 100vh;
    transition: margin-left var(--transition-normal);
    display: flex;
    flex-direction: column;
    overflow: hidden;
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
    max-width: 1600px;
    margin: 0 auto;
}

.page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 40px;
}

.header-actions {
    display: flex;
    gap: 12px;
}

.page-title {
    font-size: 32px;
    font-weight: 800;
    color: var(--gray-900);
    margin-bottom: 8px;
    letter-spacing: -0.02em;
}

.page-desc {
    font-size: 16px;
    color: var(--gray-500);
    max-width: 600px;
    line-height: 1.5;
}

.btn-primary {
    display: flex;
    align-items: center;
    gap: 8px;
    background: linear-gradient(135deg, var(--primary-600), var(--primary-500));
    color: white;
    border: none;
    padding: 12px 24px;
    border-radius: var(--radius-lg);
    font-weight: 600;
    font-size: 15px;
    cursor: pointer;
    transition: all var(--transition-fast);
    box-shadow: 0 4px 6px -1px rgba(79, 70, 229, 0.2), 0 2px 4px -1px rgba(79, 70, 229, 0.1);
    text-decoration: none;
}

.btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: 0 6px 8px -1px rgba(79, 70, 229, 0.3), 0 3px 6px -1px rgba(79, 70, 229, 0.15);
}

.btn-primary:active {
    transform: translateY(0) scale(0.98);
}

.main-grid {
    display: grid;
    grid-template-columns: 280px 1fr;
    gap: 40px;
}

.main-grid.directory-collapsed {
    grid-template-columns: 72px 1fr;
    gap: 28px;
}

/* Responsive */
@media (max-width: 1024px) {
    .content-body {
        padding: 24px;
    }
    
    .main-grid {
        grid-template-columns: 240px 1fr;
        gap: 24px;
    }

    .main-grid.directory-collapsed {
        grid-template-columns: 72px 1fr;
    }
}

@media (max-width: 768px) {
    .main-content {
        margin-left: 0; 
        /* Assuming sidebar becomes an overlay on mobile, 
           but for now keeping logic consistent with existing sidebar */
        margin-left: var(--sidebar-width-collapsed); 
    }
    
    .main-grid {
        display: flex;
        flex-direction: column;
    }
    
    .left-panel {
        width: 100%;
    }
}
</style>

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
    background-color: var(--bg-primary);
}

.main-content {
    flex: 1;
    margin-left: var(--sidebar-width);
    min-width: 0;
    background: transparent;
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
    padding: var(--layout-gap);
    overflow-y: auto;
}

.content-container {
    max-width: 1600px;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    height: 100%;
}

.page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-end;
    margin-bottom: 24px;
    padding: 0 8px;
}

.header-actions {
    display: flex;
    gap: 12px;
}

.page-title {
    font-size: 28px;
    font-weight: 700;
    color: var(--text-primary);
    margin-bottom: 4px;
    letter-spacing: -0.01em;
}

.page-desc {
    font-size: 14px;
    color: var(--text-secondary);
    max-width: 600px;
    line-height: 1.5;
}

.btn-primary {
    display: flex;
    align-items: center;
    gap: 8px;
    background: var(--text-primary);
    color: var(--text-inverse);
    border: none;
    padding: 10px 24px;
    border-radius: 24px; /* Pill Shape */
    font-weight: 600;
    font-size: 14px;
    cursor: pointer;
    transition: all var(--transition-fast);
    box-shadow: var(--shadow-sm);
    text-decoration: none;
}

.btn-primary:hover {
    transform: translateY(-1px);
    box-shadow: var(--shadow-md);
    background: #000;
}

.btn-primary:active {
    transform: translateY(0) scale(0.98);
}

.main-grid {
    display: grid;
    grid-template-columns: 300px 1fr;
    gap: var(--layout-gap);
    flex: 1;
    min-height: 0;
}

.main-grid.directory-collapsed {
    grid-template-columns: 72px 1fr;
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

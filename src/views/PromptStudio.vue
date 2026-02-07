<script setup lang="ts">
import { ref } from 'vue'
import Sidebar from '@/components/layout/Sidebar.vue'
import StudioHeader from '@/components/editor/StudioHeader.vue'
import StudioSidebar from '@/components/editor/StudioSidebar.vue'
import StudioDialogue from '@/components/editor/StudioDialogue.vue'
import StudioEditor from '@/components/editor/StudioEditor.vue'
import StudioConfig from '@/components/editor/StudioConfig.vue'

const isSidebarCollapsed = ref(false)
const currentMode = ref('dialogue')
const promptTitle = ref('未命名提示词')
const promptContent = ref('你是一位专业的SEO内容作家。\n\n请围绕主题 {{topic}} 撰写一篇博客文章，目标关键词为 {{keyword}}。\n\n约束条件：\n1. 文章结构清晰，包含引言、正文、结论\n2. 内容专业且易于阅读\n3. 适当使用标题和段落\n4. 语调：{{tone}}\n\n输出格式：JSON')
const showConfig = ref(false)

const toggleSidebar = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

const toggleConfig = () => {
  showConfig.value = !showConfig.value
}
</script>

<template>
  <div class="app-layout">
    <Sidebar :collapsed="isSidebarCollapsed" @toggle="toggleSidebar" />
    
    <main class="main-content" :class="{ collapsed: isSidebarCollapsed }">
      <div class="studio-layout">
        <StudioHeader 
          v-model:mode="currentMode"
          v-model:title="promptTitle"
          @toggle-chat="toggleConfig"
        />
        
        <div class="studio-body">
          <!-- Left Sidebar: Prompt Library -->
          <aside class="panel-card sidebar-panel">
            <StudioSidebar />
          </aside>
          
          <!-- Center: Main Workspace -->
          <main class="panel-card studio-main">
            <KeepAlive>
              <StudioDialogue v-if="currentMode === 'dialogue'" key="dialogue" />
              <StudioEditor 
                v-else 
                key="editor" 
                v-model:content="promptContent" 
                @open-config="showConfig = true"
              />
            </KeepAlive>
          </main>
          
          <!-- Right: Configuration Panel -->
          <transition name="slide-right">
            <aside class="panel-card config-panel" v-if="showConfig">
              <StudioConfig :content="promptContent" @close="showConfig = false" />
            </aside>
          </transition>
        </div>
      </div>
    </main>
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  height: 100vh;
  width: 100vw;
  overflow: hidden;
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  min-width: 0;
  background: var(--bg-primary);
  height: 100vh;
  overflow: hidden;
  transition: margin-left var(--transition-normal);
  display: flex;
  flex-direction: column;
}

.main-content.collapsed {
  margin-left: var(--sidebar-width-collapsed);
}

.studio-layout {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
  flex: 1;
}

.studio-body {
  display: flex;
  flex: 1;
  overflow: hidden;
  padding: 0 var(--layout-gap) var(--layout-gap) var(--layout-gap);
  gap: var(--layout-gap);
}

/* Panel Cards - Enhanced Visual Hierarchy & IDE Style */
.panel-card {
  background: #ffffff;
  border-radius: 8px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border: 1px solid #e5e7eb;
}

.sidebar-panel {
  width: 260px;
  flex-shrink: 0;
}

.studio-main {
  flex: 1;
  position: relative;
  background: transparent;
  border: none;
  box-shadow: none;
}

.config-panel {
  width: 300px;
  flex-shrink: 0;
  background: #ffffff;
}

/* Transitions */
.slide-right-enter-active,
.slide-right-leave-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-right-enter-from,
.slide-right-leave-to {
  transform: translateX(100%);
  opacity: 0;
}

@media (max-width: 1024px) {
  .sidebar-panel {
    display: none;
  }
}

@media (max-width: 768px) {
  .main-content {
    margin-left: var(--sidebar-width-collapsed);
  }
  .config-panel {
    position: absolute;
    right: 0;
    top: 0;
    bottom: 0;
    z-index: 10;
    box-shadow: var(--shadow-lg);
  }
}
</style>
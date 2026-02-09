<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue'
import Sidebar from '@/components/layout/Sidebar.vue'
import StudioHeader from '@/components/editor/StudioHeader.vue'
import StudioSidebar from '@/components/editor/StudioSidebar.vue'
import StudioDialogue from '@/components/editor/StudioDialogue.vue'
import StudioEditor from '@/components/editor/StudioEditor.vue'
import StudioConfig from '@/components/editor/StudioConfig.vue'
import { PanelLeftClose, PanelLeftOpen } from 'lucide-vue-next'

const isSidebarCollapsed = ref(false)
const isLeftPanelCollapsed = ref(false)
const currentMode = ref('dialogue')
const promptTitle = ref('未命名提示词')
const promptContent = ref('你是一位专业的SEO内容作家。\n\n请围绕主题 {{topic}} 撰写一篇博客文章，目标关键词为 {{keyword}}。\n\n约束条件：\n1. 文章结构清晰，包含引言、正文、结论\n2. 内容专业且易于阅读\n3. 适当使用标题和段落\n4. 语调：{{tone}}\n\n输出格式：JSON')
const showConfig = ref(false)

// Resizable Config Panel
const configPanelWidth = ref(450)
const isResizing = ref(false)

const startResize = () => {
  isResizing.value = true
  document.addEventListener('mousemove', handleResize)
  document.addEventListener('mouseup', stopResize)
  document.body.style.cursor = 'ew-resize'
  document.body.style.userSelect = 'none'
}

const handleResize = (e: MouseEvent) => {
  if (!isResizing.value) return
  
  // Calculate new width: Window width - Mouse X
  const newWidth = window.innerWidth - e.clientX
  
  // Expert Area Min Width should be around 500px for a "comfortable" experience
  const expertAreaMinWidth = 500
  
  // Calculate total occupied width by other panels
  const sidebarWidth = isSidebarCollapsed.value ? 72 : 280
  const leftPanelWidth = isLeftPanelCollapsed.value ? 20 : 260
  
  const maxAllowedWidth = window.innerWidth - sidebarWidth - leftPanelWidth - expertAreaMinWidth
  
  // Limits: Min 300px, Max dynamically calculated but at least 800px if space allows
  const minWidth = 300
  const maxWidth = Math.max(800, maxAllowedWidth)
  
  if (newWidth >= minWidth && newWidth <= maxAllowedWidth) {
    configPanelWidth.value = newWidth
  } else if (newWidth < minWidth) {
    configPanelWidth.value = minWidth
  } else if (newWidth > maxAllowedWidth) {
    // If user really wants it bigger and expert area is still > 300px (bare minimum)
    if (window.innerWidth - sidebarWidth - leftPanelWidth - newWidth > 300) {
        configPanelWidth.value = newWidth
    }
  }
}

const stopResize = () => {
  isResizing.value = false
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}

const toggleSidebar = () => {
  isSidebarCollapsed.value = !isSidebarCollapsed.value
}

const toggleConfig = () => {
  showConfig.value = !showConfig.value
}

// Auto-collapse left panel when right panel opens
watch(showConfig, (val) => {
  if (val) {
    isLeftPanelCollapsed.value = true
  }
})
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
          <div class="left-panel-wrapper" :class="{ collapsed: isLeftPanelCollapsed }">
            <aside class="panel-card sidebar-panel" v-show="!isLeftPanelCollapsed">
              <StudioSidebar />
            </aside>
            <button 
              class="panel-toggle-btn"
              @click="isLeftPanelCollapsed = !isLeftPanelCollapsed"
              :title="isLeftPanelCollapsed ? '展开侧边栏' : '收起侧边栏'"
            >
              <component :is="isLeftPanelCollapsed ? PanelLeftOpen : PanelLeftClose" :size="16" />
            </button>
          </div>
          
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
            <aside class="panel-card config-panel" v-show="showConfig" :style="{ width: configPanelWidth + 'px' }">
              <div class="resize-handle" @mousedown.prevent="startResize"></div>
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

.left-panel-wrapper {
  position: relative;
  display: flex;
  transition: width 0.3s ease;
  width: 260px;
  flex-shrink: 0;
}

.left-panel-wrapper.collapsed {
  width: 0;
  margin-right: 20px; /* Space for the toggle button */
}

.panel-toggle-btn {
  position: absolute;
  right: -12px;
  top: 50%;
  transform: translateY(-50%);
  width: 24px;
  height: 24px;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 20;
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
  color: #64748b;
  transition: all 0.2s;
}

.panel-toggle-btn:hover {
  background: #f8fafc;
  color: #3b82f6;
  border-color: #3b82f6;
}

.sidebar-panel {
  width: 100%;
  height: 100%;
}

.studio-main {
  flex: 1;
  position: relative;
  background: transparent;
  border: none;
  box-shadow: none;
}

.config-panel {
  /* width: 300px; Remove fixed width */
  flex-shrink: 0;
  background: #ffffff;
  position: relative; /* For handle positioning */
}

.resize-handle {
  position: absolute;
  left: 0;
  top: 0;
  bottom: 0;
  width: 5px;
  cursor: ew-resize;
  z-index: 10;
  transition: background-color 0.2s;
}

.resize-handle:hover,
.resize-handle:active {
  background-color: rgba(59, 130, 246, 0.2); /* Blue hint */
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
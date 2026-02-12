<script setup lang="ts">
import { ref, nextTick, watch } from 'vue'
import { useAppStore } from '@/stores/app'
import { useChatStore } from '@/stores/chat'
import { storeToRefs } from 'pinia'
import StudioHeader from '@/components/editor/StudioHeader.vue'
import StudioSidebar from '@/components/editor/StudioSidebar.vue'
import StudioDialogue from '@/components/editor/StudioDialogue.vue'
import StudioEditor from '@/components/editor/StudioEditor.vue'
import StudioConfig from '@/components/editor/StudioConfig.vue'
import SavePromptModal from '@/components/editor/SavePromptModal.vue'
import { PanelLeftClose, PanelLeftOpen } from 'lucide-vue-next'
import type { PromptItem } from '@/types/prompt'
import { useToast } from '@/composables/useToast'

const appStore = useAppStore()
const chatStore = useChatStore()
const { currentSessionTitle } = storeToRefs(chatStore)
const { toast } = useToast()

const isLeftPanelCollapsed = ref(false)
const showConfig = ref(false)
const configPanelWidth = ref(450)
const isResizing = ref(false)

const showSaveModal = ref(false)
const saveModalMessageId = ref<number | string | null>(null)

const dialogueRef = ref<InstanceType<typeof StudioDialogue> | null>(null)
const currentMode = ref('dialogue')
const promptContent = ref('你是一位专业的SEO内容作家。\n\n请围绕主题 {{topic}} 撰写一篇博客文章，目标关键词为 {{keyword}}。\n\n约束条件：\n1. 文章结构清晰，包含引言、正文、结论\n2. 内容专业且易于阅读\n3. 适当使用标题和段落\n4. 语调：{{tone}}\n\n输出格式：JSON')
const promptTitle = ref('新对话')

// Sync title with store (handles both session title and draft prompt title)
watch(currentSessionTitle, (newTitle) => {
  promptTitle.value = newTitle
}, { immediate: true })

const handleAiOptimize = async () => {
  currentMode.value = 'dialogue'
  await nextTick()
  if (dialogueRef.value) {
    dialogueRef.value.handleOptimizePrompt(promptContent.value)
  }
}

const handleOpenTest = (content: string) => {
  promptContent.value = content
  openConfig()
}

const handleSwitchExpert = (content: string) => {
  promptContent.value = content
  currentMode.value = 'editor'
}

const handleSwitchSession = (sessionId: number) => {
  currentMode.value = 'dialogue'
}

const handleNewChat = () => {
  currentMode.value = 'dialogue'
}

const handleOpenSaveModal = (messageId?: number | string) => {
  saveModalMessageId.value = messageId ?? null
  showSaveModal.value = true
}

const handlePromptSaved = (result: any) => {
  toast('提示词保存成功', 'success')

  if (result?.session_status === 1) {
    chatStore.loadSessions()
  }
}

const handleSelectPrompt = (prompt: PromptItem) => {
  promptContent.value = prompt.content || ''
  promptTitle.value = prompt.title
  currentMode.value = 'editor'
}

const openConfig = () => {
  showConfig.value = true
  configPanelWidth.value = 800
  // Auto collapse sidebars for canvas-like experience to maximize content area
  appStore.setSidebarCollapsed(true)
  isLeftPanelCollapsed.value = true
}

const closeConfig = () => {
  showConfig.value = false
  // Auto expand left panel when config is closed to avoid empty space
  // Add a small delay to make the transition smoother (wait for right panel to start exiting)
  setTimeout(() => {
    isLeftPanelCollapsed.value = false
  }, 300)
}

const startResize = () => {
  isResizing.value = true
  document.addEventListener('mousemove', handleResize)
  document.addEventListener('mouseup', stopResize)
  document.body.style.cursor = 'ew-resize'
  document.body.style.userSelect = 'none'
}

const handleResize = (e: MouseEvent) => {
  if (!isResizing.value) return
  const newWidth = window.innerWidth - e.clientX
  const minWidth = 300
  // Dynamic max width: allow stretching up to window width minus min editor width (300px)
  // This allows the sidebar to take up most of the screen like a canvas overlay
  const maxWidth = window.innerWidth - 300
  
  if (newWidth >= minWidth && newWidth <= maxWidth) {
    configPanelWidth.value = newWidth
  }
}

const stopResize = () => {
  isResizing.value = false
  document.removeEventListener('mousemove', handleResize)
  document.removeEventListener('mouseup', stopResize)
  document.body.style.cursor = ''
  document.body.style.userSelect = ''
}
</script>

<template>
  <div class="studio-layout">
    <StudioHeader 
      v-model:mode="currentMode"
      v-model:title="promptTitle"
    />
    
    <div class="studio-body">
      <!-- Left Sidebar: Prompt Library -->
      <div class="left-panel-wrapper" :class="{ collapsed: isLeftPanelCollapsed }">
        <aside class="panel-card sidebar-panel" v-show="!isLeftPanelCollapsed">
          <StudioSidebar 
            @switch-session="handleSwitchSession" 
            @new-chat="handleNewChat"
            @select-prompt="handleSelectPrompt"
          />
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
          <StudioDialogue 
            v-if="currentMode === 'dialogue'" 
            ref="dialogueRef"
            key="dialogue" 
            @update:title="(t) => promptTitle = t"
            @open-test="handleOpenTest"
            @switch-expert="handleSwitchExpert"
            @open-save="handleOpenSaveModal"
          />
          <StudioEditor 
            v-else 
            key="editor" 
            v-model:content="promptContent" 
            @open-config="openConfig"
            @ai-optimize="handleAiOptimize"
          />
        </KeepAlive>
      </main>
      
      <!-- Right Sidebar: Config & Test -->
      <Transition name="slide-right">
        <aside 
          class="panel-card config-panel" 
          v-if="showConfig"
          :style="{ width: configPanelWidth + 'px' }"
        >
          <div class="resize-handle" @mousedown="startResize"></div>
          <StudioConfig 
            :content="promptContent" 
            @close="closeConfig"
          />
        </aside>
      </Transition>
    </div>

    <SavePromptModal
      v-model:visible="showSaveModal"
      :initial-title="chatStore.currentSessionTitle"
      :initial-message-id="saveModalMessageId"
      :messages="chatStore.messages"
      :prompt-content="promptContent"
      :session-id="chatStore.currentSessionId"
      @saved="handlePromptSaved"
    />
  </div>
</template>

<style scoped>
.studio-layout {
  display: flex;
  flex-direction: column;
  height: 100%;
  overflow: hidden;
  flex: 1;
  background: var(--bg-primary);
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
  background: var(--bg-surface);
  border-radius: var(--radius-xl);
  box-shadow: var(--shadow-md);
  overflow: hidden;
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border-subtle);
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
  min-width: 0;
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
  transition: all 0.4s cubic-bezier(0.25, 0.8, 0.25, 1);
  overflow: hidden;
}

.slide-right-enter-from,
.slide-right-leave-to {
  transform: translateX(100%);
  opacity: 0;
  width: 0 !important;
  margin: 0;
  border-width: 0;
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

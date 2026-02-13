<script setup lang="ts">
import { ref, nextTick, watch, computed, onMounted } from 'vue'
import { useAppStore } from '@/stores/app'
import { useChatStore } from '@/stores/chat'
import { useUserStore } from '@/stores/user'
import { useRoute, useRouter } from 'vue-router'
import { storeToRefs } from 'pinia'
import StudioHeader from '@/components/editor/StudioHeader.vue'
import StudioSidebar from '@/components/editor/StudioSidebar.vue'
import StudioDialogue from '@/components/editor/StudioDialogue.vue'
import StudioEditor from '@/components/editor/StudioEditor.vue'
import StudioConfig from '@/components/editor/StudioConfig.vue'
import SavePromptModal from '@/components/editor/SavePromptModal.vue'
import { PanelLeftClose, PanelLeftOpen, Link, X } from 'lucide-vue-next'
import type { PromptItem } from '@/types/prompt'
import { useToast } from '@/composables/useToast'
import { getPromptDetail } from '@/api/prompt'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const chatStore = useChatStore()
const userStore = useUserStore()
const { currentSessionTitle } = storeToRefs(chatStore)
const { toast } = useToast()

const isLeftPanelCollapsed = ref(false)
const showConfig = ref(false)
const configPanelWidth = ref(450)
const isResizing = ref(false)

const showSaveModal = ref(false)
const saveModalMessageId = ref<number | string | null>(null)
const referencedPrompt = ref<PromptItem | null>(null)

// 是否为引用他人提示词（自己的提示词不显示引用横幅）
// 通过 session_id 进入时（已保存的提示词会话），不显示引用横幅
const showRefBanner = computed(() => {
  if (route.query.session_id) return false
  const hasPromptId = !!route.query.promptId
  if (!hasPromptId) return false
  if (!referencedPrompt.value) return false
  const currentUserId = userStore.userInfo?.id
  return String(currentUserId) !== String(referencedPrompt.value.author?.id)
})

const handleCloseRefBanner = () => {
  const query = { ...route.query }
  delete query.promptId
  router.replace({ query })
}

const dialogueRef = ref<InstanceType<typeof StudioDialogue> | null>(null)
const currentMode = ref('dialogue')
const promptContent = ref('你是一位专业的SEO内容作家。\n\n请围绕主题 {{topic}} 撰写一篇博客文章，目标关键词为 {{keyword}}。\n\n约束条件：\n1. 文章结构清晰，包含引言、正文、结论\n2. 内容专业且易于阅读\n3. 适当使用标题和段落\n4. 语调：{{tone}}\n\n输出格式：JSON')
const promptTitle = ref('新对话')
const lockedMessageId = ref<number | string | null>(null)

// Sync title with store (handles both session title and draft prompt title)
watch(currentSessionTitle, (newTitle) => {
  promptTitle.value = newTitle
}, { immediate: true })

// Auto-sync prompt content with last message if not locked
watch(() => chatStore.messages, (newMessages) => {
  if (!lockedMessageId.value && newMessages.length > 0) {
    const lastMsg = newMessages[newMessages.length - 1] as any
    if (lastMsg && !lastMsg.isStreaming) {
      if (lastMsg.type === 'prompt-ref' && lastMsg.promptData?.content) {
        promptContent.value = lastMsg.promptData.content
      } else if (lastMsg.content) {
        promptContent.value = lastMsg.content
      }
    }
  }
}, { deep: true, immediate: true })

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

const handleSwitchExpert = (content: string, messageId?: number | string) => {
  promptContent.value = content
  currentMode.value = 'editor'
  if (messageId) {
    lockedMessageId.value = messageId
  }
}

const handleSwitchSession = (sessionId: number) => {
  currentMode.value = 'dialogue'
  lockedMessageId.value = null
}

const handleNewChat = () => {
  currentMode.value = 'dialogue'
  lockedMessageId.value = null
}

const handleOpenSaveModal = (messageId?: number | string) => {
  saveModalMessageId.value = messageId ?? null
  showSaveModal.value = true
}

const handlePromptSaved = (result: any) => {
  toast('提示词保存成功', 'success')

  if (result?.prompt_id && chatStore.currentSessionId) {
    // 立即更新当前会话的 origin_prompt_id，确保下次保存时能正确更新而不是新建
    chatStore.updateSessionPromptId(chatStore.currentSessionId, result.prompt_id)
  }

  if (result?.session_status === 1) {
    chatStore.loadSessions()
  }
}

const handleSelectPrompt = (prompt: PromptItem) => {
  promptContent.value = prompt.content || ''
  promptTitle.value = prompt.title
  currentMode.value = 'editor'
  // Lock content when selecting from library to prevent auto-update from chat
  lockedMessageId.value = `prompt-${prompt.id}`
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

// 组件挂载时，如果有 promptId，主动获取提示词详情
onMounted(async () => {
  const promptId = route.query.promptId
  if (promptId) {
    try {
      const id = parseInt(promptId as string)
      if (!isNaN(id)) {
        const prompt = await getPromptDetail(id)
        referencedPrompt.value = prompt
      }
    } catch (e) {
      console.error('Failed to load prompt detail in PromptStudio:', e)
    }
  }
})
</script>

<template>
  <div class="studio-layout">
    <StudioHeader 
      v-model:mode="currentMode"
      v-model:title="promptTitle"
    />
    
    <div v-if="showRefBanner" class="ref-banner">
      <div class="ref-content">
        <Link :size="16" />
        <span>正在引用提示词：{{ promptTitle }}</span>
      </div>
      <button class="ref-close-btn" @click="handleCloseRefBanner" title="知道了">
        <X :size="16" />
      </button>
    </div>
    
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
      <main class="panel-card studio-main" :class="{ 'ref-glow': showRefBanner }">
        <KeepAlive>
          <StudioDialogue 
            v-if="currentMode === 'dialogue'" 
            ref="dialogueRef"
            key="dialogue" 
            @update:title="(t) => promptTitle = t"
            @open-test="handleOpenTest"
            @switch-expert="handleSwitchExpert"
            @open-save="handleOpenSaveModal"
            @prompt-loaded="(prompt) => referencedPrompt = prompt"
          />
          <StudioEditor 
            v-else 
            key="editor" 
            v-model:content="promptContent" 
            @open-config="openConfig"
            @ai-optimize="handleAiOptimize"
            @open-save="handleOpenSaveModal"
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
      :prompt-id="chatStore.currentSession?.origin_prompt_id || null"
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

.ref-banner {
  background: linear-gradient(90deg, var(--primary-light) 0%, var(--bg-surface) 100%);
  border-bottom: 1px solid rgba(var(--primary-rgb), 0.2);
  padding: 8px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--primary);
  font-size: 13px;
  font-weight: 500;
  animation: slideDown 0.3s ease-out;
}

.ref-content {
  display: flex;
  align-items: center;
  gap: 8px;
}

.ref-close-btn {
  background: none;
  border: none;
  color: var(--text-secondary);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.ref-close-btn:hover {
  background: rgba(0, 0, 0, 0.05);
  color: var(--text-primary);
}

.ref-glow {
  position: relative;
  border: 1px solid var(--primary) !important;
  box-shadow: 0 0 0 2px var(--primary-light), 0 4px 12px rgba(var(--primary-rgb), 0.1);
  animation: glowPulse 2s infinite;
  z-index: 1;
}

@keyframes slideDown {
  from { transform: translateY(-100%); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes glowPulse {
  0% { box-shadow: 0 0 0 0px var(--primary-light); }
  50% { box-shadow: 0 0 0 4px var(--primary-light); }
  100% { box-shadow: 0 0 0 0px var(--primary-light); }
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

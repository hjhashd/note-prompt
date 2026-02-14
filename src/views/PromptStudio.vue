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
import { PanelLeftClose, PanelLeftOpen, Link, X, Loader2 } from 'lucide-vue-next'
import type { PromptItem } from '@/types/prompt'
import { useToast } from '@/composables/useToast'
import { getPromptDetail } from '@/api/prompt'
import { getSessionByPromptId } from '@/api/lyf-ai'

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
const isLoading = ref(false)

const showSaveModal = ref(false)
const saveModalMessageId = ref<number | string | null>(null)
const saveModalMode = ref<'dialogue' | 'editor' | 'test'>('dialogue')
const referencedPrompt = ref<PromptItem | null>(null)

// Preview History Navigation
const previewHistory = ref<PromptItem[]>([])
const previewHistoryIndex = ref(-1)

const showRefBanner = computed(() => {
  if (route.query.session_id) return false
  if (chatStore.currentSessionId) return false
  const hasPromptId = !!route.query.promptId
  if (!hasPromptId) return false
  if (!referencedPrompt.value) return false
  const currentUserId = userStore.userInfo?.id
  return String(currentUserId) !== String(referencedPrompt.value.author?.id)
})

watch(() => route.query.session_id, (sessionId) => {
  if (sessionId) {
    referencedPrompt.value = null
  }
}, { immediate: true })

watch(() => chatStore.currentSessionId, (sessionId) => {
  if (sessionId) {
    referencedPrompt.value = null
  }
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
    if (lastMsg && !lastMsg.isStreaming && lastMsg.content) {
      promptContent.value = lastMsg.content
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
  // 根据当前模式设置保存模式
  saveModalMode.value = currentMode.value === 'editor' ? 'editor' : 'dialogue'
  showSaveModal.value = true
}

const handlePromptSaved = (result: any) => {
  toast(result?.data?.is_update ? '提示词更新成功' : '提示词保存成功', 'success')

  if (result?.prompt_id || result?.data?.prompt_id) {
    const promptId = result?.prompt_id || result?.data?.prompt_id
    
    if (chatStore.currentSessionId) {
      // 立即更新当前会话的 origin_prompt_id，确保下次保存时能正确更新而不是新建
      chatStore.updateSessionPromptId(chatStore.currentSessionId, promptId)
    }
    
    // 编辑器模式下，设置或更新 referencedPrompt 以便下次保存时能正确更新
    if (saveModalMode.value === 'editor') {
      if (referencedPrompt.value) {
        // 更新现有提示词ID
        referencedPrompt.value = {
          ...referencedPrompt.value,
          id: promptId
        }
      } else {
        // 新建提示词后，创建一个基本的 referencedPrompt 对象
        referencedPrompt.value = {
          id: promptId,
          title: promptTitle.value,
          content: promptContent.value,
          author: {
            id: userStore.userInfo?.id,
            name: userStore.userInfo?.name || userStore.userInfo?.username
          }
        } as PromptItem
      }
    }
  }

  if (result?.session_status === 1 || result?.data?.session_status === 1) {
    chatStore.loadSessions()
  }
}

const loadTempSession = async (prompt: PromptItem) => {
  const currentUserId = userStore.userInfo?.id
  const isOwnPrompt = String(currentUserId) === String(prompt.author?.id || prompt.user_id)

  if (isOwnPrompt) {
    chatStore.openDraftSession()
    chatStore.draftTitle = prompt.title || '新对话'
    referencedPrompt.value = prompt
    lockedMessageId.value = null
    currentMode.value = 'dialogue'
    const query = { ...route.query }
    delete query.session_id
    delete query.promptId
    await router.replace({ query })
    chatStore.setTempSession({
      id: `temp-own-${prompt.id}`,
      title: prompt.title,
      promptId: prompt.id,
      isOwnPrompt: true,
      promptData: prompt
    })
    chatStore.messages = [
      { 
        id: Date.now(), 
        role: 'ai', 
        content: prompt.content || '', 
        type: 'text'
      }
    ]
  } else {
    promptContent.value = prompt.content || ''
    promptTitle.value = prompt.title
    currentMode.value = 'editor'
    referencedPrompt.value = prompt
    lockedMessageId.value = `prompt-${prompt.id}`
    chatStore.setTempSession({
      id: `temp-ref-${prompt.id}`,
      title: prompt.title,
      promptId: prompt.id,
      isOwnPrompt: false,
      promptData: prompt
    })
  }
}

const handleSelectPrompt = async (prompt: PromptItem) => {
  const currentUserId = userStore.userInfo?.id
  const isOwnPrompt = String(currentUserId) === String(prompt.author?.id || prompt.user_id)
  
  if (isOwnPrompt) {
    try {
      const sessionResult = await getSessionByPromptId(prompt.id)
      if (sessionResult.found && sessionResult.session) {
        const sid = sessionResult.session.session_id
        chatStore.currentSessionId = sid
        await chatStore.loadSessionHistory(sid)
        await router.replace({ query: { session_id: String(sid) } })
        referencedPrompt.value = prompt
        lockedMessageId.value = null
        currentMode.value = 'dialogue'
        chatStore.clearTempSession()
        return
      }
    } catch (e) {
      console.error('Failed to check session for prompt:', e)
    }
  }

  // Add to history
  if (previewHistoryIndex.value < previewHistory.value.length - 1) {
    previewHistory.value = previewHistory.value.slice(0, previewHistoryIndex.value + 1)
  }
  
  const current = previewHistory.value[previewHistoryIndex.value]
  if (!current || current.id !== prompt.id) {
    previewHistory.value.push(prompt)
    previewHistoryIndex.value++
  }
  
  await loadTempSession(prompt)
}

const handlePreviewBack = () => {
  if (previewHistoryIndex.value > 0) {
    previewHistoryIndex.value--
    loadTempSession(previewHistory.value[previewHistoryIndex.value])
  }
}

const handlePreviewForward = () => {
  if (previewHistoryIndex.value < previewHistory.value.length - 1) {
    previewHistoryIndex.value++
    loadTempSession(previewHistory.value[previewHistoryIndex.value])
  }
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
  
  // 检查是否有预加载的数据 (from PromptList navigation)
  const state = history.state as { initialPrompt?: PromptItem; initialContent?: string; initialTitle?: string } | null
  
  if (promptId) {
    // 优先使用预加载数据，实现即时渲染
    if (state?.initialPrompt && String(state.initialPrompt.id) === String(promptId)) {
      referencedPrompt.value = state.initialPrompt
      // Initial prompt to history if it's a preview
      if (!route.query.session_id && previewHistory.value.length === 0) {
        previewHistory.value.push(state.initialPrompt)
        previewHistoryIndex.value = 0
      }
      // 如果有内容和标题，也可以预设，避免闪烁
      if (state.initialContent) promptContent.value = state.initialContent
      if (state.initialTitle) promptTitle.value = state.initialTitle
      return
    }

    // 如果没有预加载数据，则进行常规获取
    try {
      isLoading.value = true
      const id = parseInt(promptId as string)
      if (!isNaN(id)) {
        const prompt = await getPromptDetail(id)
        if (prompt) {
          referencedPrompt.value = prompt
          // Initial prompt to history if it's a preview
          if (!route.query.session_id && previewHistory.value.length === 0) {
            previewHistory.value.push(prompt)
            previewHistoryIndex.value = 0
          }
        }
      }
    } catch (e) {
      console.error('Failed to load prompt detail in PromptStudio:', e)
    } finally {
      isLoading.value = false
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
    
    <div class="studio-body">
      <!-- Left Sidebar: Prompt Library -->
      <div class="left-panel-wrapper" :class="{ collapsed: isLeftPanelCollapsed }">
        <aside class="panel-card sidebar-panel" v-show="!isLeftPanelCollapsed">
          <StudioSidebar 
            @switch-session="handleSwitchSession" 
            @new-chat="handleNewChat"
            @select-prompt="handleSelectPrompt"
            :can-go-back="previewHistoryIndex > 0"
            :can-go-forward="previewHistoryIndex < previewHistory.length - 1"
            @preview-back="handlePreviewBack"
            @preview-forward="handlePreviewForward"
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
        <div v-if="showRefBanner" class="ref-banner">
          <div class="ref-content">
            <div class="ref-icon-wrapper">
              <Link :size="16" />
            </div>
            <div class="ref-text">
              <span class="ref-title">正在引用提示词：{{ referencedPrompt?.title || promptTitle }}</span>
              <span class="ref-hint">你可以基于此提示词进行优化、测试，保存后将生成你自己的版本</span>
            </div>
          </div>
          <button class="ref-close-btn" @click="handleCloseRefBanner" title="退出引用模式">
            <X :size="16" />
          </button>
        </div>

        <div v-if="isLoading" class="loading-overlay">
          <Loader2 class="animate-spin text-primary" :size="32" />
          <span class="loading-text">加载中...</span>
        </div>
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
      :prompt-id="saveModalMode === 'editor' ? (referencedPrompt?.id || null) : (chatStore.currentSession?.origin_prompt_id || null)"
      :mode="saveModalMode"
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
  background: linear-gradient(90deg, var(--primary-50) 0%, var(--bg-surface) 100%);
  border-bottom: 1px solid var(--primary-100);
  padding: 12px 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  color: var(--primary-700);
  font-size: 13px;
  animation: slideDown 0.3s ease-out;
  min-height: 56px;
  flex-shrink: 0;
}

.ref-content {
  display: flex;
  align-items: center;
  gap: 12px;
}

.ref-icon-wrapper {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  background: var(--primary-100);
  color: var(--primary-600);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.ref-text {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.ref-title {
  font-weight: 600;
  color: var(--primary-900);
}

.ref-hint {
  font-size: 12px;
  color: var(--primary-600);
  font-weight: 400;
}

.ref-close-btn {
  background: transparent;
  border: 1px solid transparent;
  color: var(--primary-500);
  cursor: pointer;
  width: 28px;
  height: 28px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.ref-close-btn:hover {
  background: var(--primary-100);
  color: var(--primary-700);
}

.ref-glow {
  position: relative;
  /* border: 1px solid var(--primary-200) !important; */
  /* Remove intense glow, keep it subtle or use the banner as the main indicator */
  box-shadow: 0 0 0 1px var(--primary-100), 0 4px 12px rgba(var(--primary-rgb), 0.05);
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

.loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.8);
  backdrop-filter: blur(4px);
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  z-index: 50;
  gap: 12px;
}

.loading-text {
  color: var(--text-secondary);
  font-size: 14px;
}
</style>

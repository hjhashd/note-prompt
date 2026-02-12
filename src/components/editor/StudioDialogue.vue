<script setup lang="ts">
import { ref, nextTick, watch, onUnmounted, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { chatStream, optimizeStream, autoGenerateTitle } from '@/api/lyf-ai'
import { getPromptDetail } from '@/api/prompt'
import AiContentRenderer from '@/components/editor/AiContentRenderer.vue'
import PromptReferenceCard from '@/components/editor/PromptReferenceCard.vue'
import { ArrowDown, FlaskConical, Code2, Save } from 'lucide-vue-next'
import { useChatStore } from '@/stores/chat'
import { storeToRefs } from 'pinia'

const props = defineProps<{
  initialPrompt?: string
}>()

const emit = defineEmits<{
  (e: 'update:title', title: string): void
  (e: 'open-test', content: string): void
  (e: 'switch-expert', content: string): void
  (e: 'open-save', messageId: number | string): void
}>()

const route = useRoute()
const router = useRouter()
const messagesContainer = ref<HTMLElement | null>(null)

const chatStore = useChatStore()
const { messages, currentSessionId, isOptimizing, pendingQueue } = storeToRefs(chatStore)

// Scroll State Management
const shouldAutoScroll = ref(true)
const showScrollButton = ref(false)

const handleScroll = () => {
  if (!messagesContainer.value) return
  const el = messagesContainer.value
  const { scrollTop, scrollHeight, clientHeight } = el
  
  // Check if user is at the bottom (threshold 50px)
  const isAtBottom = scrollHeight - scrollTop - clientHeight < 50
  
  if (isAtBottom) {
    shouldAutoScroll.value = true
    showScrollButton.value = false
  } else {
    // If user scrolls up, disable auto-scroll
    shouldAutoScroll.value = false
    
    // Show button if we are generating content or if there is new content pending
    if (isOptimizing.value || pendingQueue.value.length > 0) {
      showScrollButton.value = true
    }
  }
}

const scrollToBottom = async (force = false) => {
  await nextTick()
  if (messagesContainer.value) {
    const el = messagesContainer.value
    
    // If forced (button click) or auto-scroll is enabled
    if (force || shouldAutoScroll.value) {
      if (force) {
        el.scrollTo({
          top: el.scrollHeight,
          behavior: 'smooth'
        })
        shouldAutoScroll.value = true
        showScrollButton.value = false
      } else {
        el.scrollTop = el.scrollHeight
      }
    } else {
      if (isOptimizing.value || pendingQueue.value.length > 0) {
        showScrollButton.value = true
      }
    }
  }
}

const input = ref('')
const inputRef = ref<HTMLTextAreaElement | null>(null)

const adjustInputHeight = () => {
  const textarea = inputRef.value
  if (!textarea) return
  
  // Reset height to get correct scrollHeight
  textarea.style.height = 'auto'
  // Set new height based on scrollHeight
  textarea.style.height = `${textarea.scrollHeight}px`
}

watch(input, () => {
  nextTick(adjustInputHeight)
})

const handleUsePrompt = (content: string) => {
  input.value = content
  nextTick(() => {
    inputRef.value?.focus()
    adjustInputHeight()
  })
}

const handleOptimizePrompt = (content: string) => {
  input.value = content
  nextTick(() => {
    adjustInputHeight()
    inputRef.value?.focus()
  })
}

// Optimized Queue System
let rafId: number | null = null

const processQueue = () => {
  if (pendingQueue.value.length === 0) {
    rafId = null
    return
  }

  // Calculate total pending size to adjust speed
  const totalPending = pendingQueue.value.reduce((acc, item) => acc + item.text.length, 0)
  
  // Dynamic speed: If backlog is large, process faster.
  const charsPerFrame = totalPending > 1000 ? 100 : (totalPending > 200 ? 20 : 3)
  
  let charsProcessed = 0
  const processedMsgIds = new Set<number>()

  while (charsProcessed < charsPerFrame && pendingQueue.value.length > 0) {
    const item = pendingQueue.value[0]
    const msg = messages.value.find(m => m.id === item.msgId)
    
    if (!msg) {
      pendingQueue.value.shift() // Invalid message, drop
      continue
    }

    // Determine how many chars to take from this item
    const remainingInItem = item.text.length
    const canTake = charsPerFrame - charsProcessed
    const take = Math.min(remainingInItem, canTake)
    
    const chunk = item.text.slice(0, take)
    msg.content += chunk
    
    // Update item in queue
    if (take === remainingInItem) {
      pendingQueue.value.shift() // Done with this item
    } else {
      item.text = item.text.slice(take)
    }
    
    charsProcessed += take
    processedMsgIds.add(msg.id)
  }

  if (processedMsgIds.size > 0) {
    scrollToBottom()
  }

  rafId = requestAnimationFrame(processQueue)
}

watch(() => messages.value.length, () => scrollToBottom(true))

const sendMessage = async () => {
  if (!input.value.trim() || isOptimizing.value) return
  
  const prompt = input.value
  const userMsg = { id: Date.now(), role: 'user', content: prompt }
  messages.value.push(userMsg)
  
  input.value = ''
  isOptimizing.value = true
  
  // Create placeholder for AI response
  const aiMsgId = Date.now() + 1
  const aiMsg: any = { 
    id: aiMsgId, 
    role: 'ai', 
    content: '',
    isStreaming: true
  }
  messages.value.push(aiMsg)
  
  const currentAiMsgIndex = messages.value.length - 1
  
  // Call real API
  const isFirstMessage = !currentSessionId.value

  await chatStream(
    { query: prompt, session_id: currentSessionId.value || undefined },
    (chunk) => {
      // Push raw chunk to queue
      pendingQueue.value.push({ msgId: aiMsgId, text: chunk })
      
      // Ensure animation loop is running
      if (!rafId) {
        rafId = requestAnimationFrame(processQueue)
      }
    },
    async (meta) => {
      const sid = Number(meta?.session_id)
      if (!sid || currentSessionId.value) return
      // Update session ID in store and reload sessions list
      chatStore.currentSessionId = sid
      await chatStore.loadSessions()
      
      // Update URL
      const query: Record<string, any> = { ...route.query }
      query.session_id = String(sid)
      await router.replace({ query })
    },
    () => {
      // Stream finished
      const checkDone = async () => {
        if (pendingQueue.value.length === 0) {
          isOptimizing.value = false
          const msg = messages.value[currentAiMsgIndex]
          if (msg) msg.isStreaming = false
          
          // Auto-generate title for the first message
          if (isFirstMessage && currentSessionId.value) {
            try {
              // Use user prompt + AI response as context (limit length to avoid huge payload)
              const aiContent = msg ? msg.content : ''
              const context = `User: ${prompt}\nAI: ${aiContent}`.slice(0, 2000)
              
              const res = await autoGenerateTitle(currentSessionId.value, context)
              if (res.ok && res.new_title) {
                // Update local title
                emit('update:title', res.new_title)
                // Update store sessions list
                await chatStore.loadSessions()
              }
            } catch (e) {
              console.warn('Failed to auto-generate title:', e)
            }
          } else {
            // Reload sessions to update update_time
            chatStore.loadSessions()
          }
        } else {
          requestAnimationFrame(checkDone)
        }
      }
      checkDone()
    },
    (error) => {
      console.error('Chat error:', error)
      const msg = messages.value[currentAiMsgIndex]
      if (msg) {
        const errorText = '\n[错误: 无法获取响应]'
        pendingQueue.value.push({ msgId: aiMsgId, text: errorText })
      }
      isOptimizing.value = false
      if (msg) msg.isStreaming = false
      scrollToBottom()
    }
  )
}

defineExpose({
  handleOptimizePrompt
})

onMounted(async () => {
  await chatStore.loadSessions()
  
  // Priority 1: Check for promptId (New Chat from Prompt)
  const promptId = route.query.promptId
  if (promptId) {
    // Force reset to draft mode to avoid mixing with previous session
    chatStore.openDraftSession()
    
    try {
      const id = parseInt(promptId as string)
      if (!isNaN(id)) {
        const prompt = await getPromptDetail(id)
        
        // Set draft title
        chatStore.draftTitle = prompt.title || '新对话'
        
        messages.value.push({
          id: Date.now(),
          role: 'ai',
          content: '已加载该提示词上下文，你可以直接使用或让我帮你优化：',
          type: 'prompt-ref',
          promptData: prompt
        })
      }
    } catch (e) {
      console.error('Failed to load prompt detail:', e)
    }
    return // Stop here, ignore session_id if promptId is present (user intent is to use prompt)
  }

  // Priority 2: Check for session_id (Existing Chat)
  const routeSessionId = route.query.session_id
  if (routeSessionId) {
    const sid = parseInt(String(routeSessionId))
    if (!isNaN(sid)) {
      chatStore.currentSessionId = sid
      await chatStore.loadSessionHistory(sid)
    }
  } else {
    // If no session ID and no prompt ID, check if we already have messages (from store)
    // If not, reset to welcome. This prevents double welcome if store already has it.
    if (!currentSessionId.value && messages.value.length === 0) {
      chatStore.resetToWelcome()
    }
  }
})

onUnmounted(() => {
  if (rafId) cancelAnimationFrame(rafId)
})
</script>

<template>
  <div class="chat-container">
    <div class="chat-body">
      <div class="chat-main">
        <div 
          class="chat-messages" 
          ref="messagesContainer" 
          @scroll="handleScroll"
        >
          <div 
            v-for="msg in messages" 
            :key="msg.id" 
            class="chat-message" 
            :class="msg.role"
          >
            <div v-if="msg.role === 'ai'" class="ai-icon">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.21 1.21 0 0 0 1.72 0L21.64 5.36a1.21 1.21 0 0 0 0-1.72Z"></path>
                <path d="m14 7 3 3"></path>
                <path d="M5 6v4"></path>
                <path d="M19 14v4"></path>
                <path d="M10 2v2"></path>
                <path d="M7 8H3"></path>
                <path d="M21 16h-4"></path>
                <path d="M11 3H9"></path>
              </svg>
            </div>
            <div class="chat-bubble">
              <div v-if="msg.type === 'prompt-ref' && msg.promptData">
                <PromptReferenceCard 
                  :prompt="msg.promptData" 
                  compact
                />
              </div>

              <AiContentRenderer 
                v-else-if="msg.role === 'ai'" 
                :content="msg.content"
                :is-streaming="msg.isStreaming"
                :show-copy="msg.type !== 'welcome'"
              >
                <template #actions v-if="!msg.isStreaming && msg.type !== 'welcome' && msg.type !== 'prompt-ref'">
                  <button class="action-btn-pill" @click="emit('open-test', msg.content)" title="在测试台中打开">
                    <FlaskConical :size="14" />
                    <span>测试</span>
                  </button>
                  <button class="action-btn-pill" @click="emit('switch-expert', msg.content)" title="切换到专家模式编辑">
                    <Code2 :size="14" />
                    <span>专家模式</span>
                  </button>
                  <button class="action-btn-pill" type="button" title="保存" @click="emit('open-save', msg.id)">
                    <Save :size="14" />
                    <span>保存</span>
                  </button>
                </template>
              </AiContentRenderer>

              <div v-else-if="msg.role !== 'ai'" style="white-space: pre-wrap;">{{ msg.content }}</div>
            </div>
          </div>
        </div>

        <Transition name="fade-slide">
          <button 
            v-if="showScrollButton" 
            class="scroll-bottom-btn"
            @click="scrollToBottom(true)"
            type="button"
          >
            <ArrowDown :size="16" />
            <span>新内容生成中</span>
          </button>
        </Transition>

        <div class="chat-input-area">
          <div class="chat-input-wrapper">
            <textarea 
              ref="inputRef"
              class="chat-input" 
              v-model="input"
              placeholder="描述你的需求，或使用 @ 引用提示词..."
              @keydown.enter.prevent="sendMessage"
            ></textarea>
            
            <div class="chat-input-actions">
              <button class="action-btn" title="优化" type="button">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
                </svg>
              </button>
              <button class="action-btn" title="导入/导出" type="button">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"></path>
                  <polyline points="16 6 12 2 8 6"></polyline>
                  <line x1="12" y1="2" x2="12" y2="15"></line>
                </svg>
              </button>
              <button class="chat-send-btn" type="button" @click="sendMessage" :disabled="!input.trim() || isOptimizing">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <line x1="22" y1="2" x2="11" y2="13"></line>
                  <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                </svg>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>


<style scoped>
.action-btn-pill {
  display: flex;
  align-items: center;
  gap: 6px;
  background: var(--bg-secondary);
  border: 1px solid rgba(0, 0, 0, 0.03);
  color: var(--text-secondary);
  padding: 0 14px;
  border-radius: 24px;
  cursor: pointer;
  transition: all 0.2s ease;
  height: 32px;
  font-size: 13px;
  font-weight: 500;
}

.action-btn-pill:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
  transform: translateY(-1px);
  box-shadow: 0 2px 4px rgba(0,0,0,0.05);
}


.chat-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: transparent; /* Parent card has background */
  position: relative;
}

.chat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  border-bottom: 1px solid var(--border-subtle);
}

.chat-header-title {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 70%;
}

.new-session-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 10px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  color: var(--text-primary);
  font-size: 13px;
  cursor: pointer;
}

.new-session-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.chat-body {
  flex: 1;
  display: flex;
  min-height: 0;
}

.sessions-panel {
  width: 260px;
  border-right: 1px solid var(--border-subtle);
  background: var(--bg-primary);
  min-height: 0;
  display: flex;
}

.sessions-list {
  flex: 1;
  overflow-y: auto;
  padding: 10px;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.sessions-empty {
  padding: 10px;
  color: var(--text-secondary);
  font-size: 13px;
}

.session-item {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 8px;
  padding: 10px;
  border-radius: 12px;
  border: 1px solid transparent;
  background: transparent;
  cursor: pointer;
  text-align: left;
  color: var(--text-primary);
}

.session-item:hover {
  background: var(--bg-surface);
  border-color: var(--border-subtle);
}

.session-item.active {
  background: var(--bg-surface);
  border-color: var(--primary);
}

.session-item-title {
  font-size: 13px;
  line-height: 1.3;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  flex: 1;
}

.session-item-actions {
  display: inline-flex;
  gap: 6px;
  flex-shrink: 0;
}

.icon-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 8px;
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  color: var(--text-secondary);
  cursor: pointer;
}

.icon-btn:hover {
  color: var(--text-primary);
}

.icon-btn.danger:hover {
  color: #ef4444;
  border-color: rgba(239, 68, 68, 0.6);
}

.chat-main {
  flex: 1;
  min-width: 0;
  min-height: 0;
  position: relative;
  display: flex;
  flex-direction: column;
}

.scroll-bottom-btn {
  position: absolute;
  bottom: 120px; /* Above input area */
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 20px;
  box-shadow: var(--shadow-md);
  color: var(--primary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  z-index: 10;
  transition: all 0.2s;
}

.scroll-bottom-btn:hover {
  background: var(--bg-primary);
  transform: translateX(-50%) translateY(-2px);
  box-shadow: var(--shadow-lg);
}

.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.3s ease;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(10px);
}

.chat-messages {
  flex: 1;
  min-height: 0;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  /* align-items: center; Removed to keep left alignment */
}

.chat-message {
  display: flex;
  width: 100%;
  max-width: 800px; /* Gemini style max-width */
  animation: fadeIn 0.3s ease;
  position: relative;
  gap: 12px;
}

.chat-message.user {
  align-self: flex-end;
  justify-content: flex-end;
}

.ai-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary); /* Neutral gray to match your image */
  flex-shrink: 0;
  margin-top: 4px;
}

.chat-bubble {
  padding: 12px 16px;
  border-radius: 16px;
  font-size: 14px;
  line-height: 1.6;
  position: relative;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
}

.chat-message.ai .chat-bubble {
  background: var(--bg-surface);
  color: var(--text-primary);
  border-top-left-radius: 4px;
}

.chat-message.user .chat-bubble {
  background: var(--primary);
  color: white;
  border-top-right-radius: 4px;
  border-color: transparent;
}

.chat-input-area {
  padding: 20px;
  background: transparent;
  display: flex;
  justify-content: center; /* Center the input area */
  width: 100%;
}

.chat-input-wrapper {
  position: relative;
  background: var(--bg-surface);
  border-radius: 24px;
  padding: 4px;
  transition: all 0.2s;
  border: 1px solid var(--border-subtle);
  width: 100%;
  max-width: 800px;
}

.chat-input-wrapper:focus-within {
  background: var(--bg-surface);
  box-shadow: 0 0 0 2px var(--primary-light);
  border-color: var(--primary);
}

.chat-input {
  width: 100%;
  min-height: 48px;
  max-height: 200px;
  padding: 12px 100px 12px 16px;
  border: none;
  background: transparent;
  resize: none;
  font-size: 14px;
  color: var(--text-primary);
  line-height: 1.5;
  overflow-y: auto;
  transition: height 0.1s ease;
}

/* Hide scrollbar for Chrome, Safari and Opera */
.chat-input::-webkit-scrollbar {
  width: 4px;
}

.chat-input::-webkit-scrollbar-thumb {
  background: var(--border-subtle);
  border-radius: 10px;
}

.chat-input:focus {
  outline: none;
}

.chat-input-actions {
  position: absolute;
  right: 8px;
  bottom: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.action-btn:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.chat-send-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--text-primary); /* Black button like NotebookLM */
  color: white;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}

.chat-send-btn:hover:not(:disabled) {
  transform: scale(1.05);
  background: black;
}

.chat-send-btn:disabled {
  background: var(--text-tertiary);
  cursor: not-allowed;
  opacity: 0.7;
}

/* 思考过程样式 */
.thinking-section {
  margin-bottom: 12px;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background-color: var(--bg-subtle);
  overflow: hidden;
}

.thinking-header {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  cursor: pointer;
  user-select: none;
  background-color: rgba(0, 0, 0, 0.02);
  transition: background-color 0.2s;
}

.thinking-header:hover {
  background-color: rgba(0, 0, 0, 0.05);
}

.thinking-icon {
  margin-right: 8px;
  font-size: 14px;
}

.thinking-title {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  flex: 1;
}

.thinking-arrow {
  font-size: 10px;
  color: var(--text-tertiary);
  transition: transform 0.2s;
}

.thinking-arrow.rotated {
  transform: rotate(180deg);
}

.thinking-body {
  padding: 12px;
  font-size: 13px;
  line-height: 1.6;
  color: var(--text-secondary);
  background-color: var(--bg-surface);
  border-top: 1px solid var(--border-subtle);
  white-space: pre-wrap;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Markdown 样式覆盖 (可选) */
.markdown-body :deep(p) {
  margin-bottom: 1em;
}
.markdown-body :deep(p:last-child) {
  margin-bottom: 0;
}

.loading-state {
    display: flex;
    flex-direction: column;
    align-items: flex-start; /* Left align in bubble */
    padding: 4px 0;
    gap: 8px;
}

.loading-text {
    font-size: 13px;
    color: var(--text-tertiary);
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

.typing-indicator {
    display: flex;
    gap: 4px;
}

.typing-indicator span {
    width: 6px;
    height: 6px;
    background-color: var(--primary);
    border-radius: 50%;
    animation: bounce 1.4s infinite ease-in-out both;
}

.typing-indicator span:nth-child(1) { animation-delay: -0.32s; }
.typing-indicator span:nth-child(2) { animation-delay: -0.16s; }

@keyframes bounce {
    0%, 80%, 100% { transform: scale(0); }
    40% { transform: scale(1); }
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: .5; }
}
</style>

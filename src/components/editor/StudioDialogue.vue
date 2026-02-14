<script setup lang="ts">
import { ref, nextTick, watch, onUnmounted, onMounted, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { chatStream, autoGenerateTitle, regenerateChatStream, getSessionByPromptId } from '@/api/lyf-ai'
import { getPromptDetail, getPrompts } from '@/api/prompt'
import type { PromptItem } from '@/types/prompt'
import { useUserStore } from '@/stores/user'
import AiContentRenderer from '@/components/editor/AiContentRenderer.vue'
import PromptReferenceCard from '@/components/editor/PromptReferenceCard.vue'
import CopyButton from '@/components/common/CopyButton.vue'
import { ArrowDown, FlaskConical, Code2, Save, Sparkles, SendHorizontal, Pencil, RotateCw, Square } from 'lucide-vue-next'
import { useChatStore } from '@/stores/chat'
import { storeToRefs } from 'pinia'

const emit = defineEmits<{
  (e: 'update:title', title: string): void
  (e: 'open-test', content: string): void
  (e: 'switch-expert', content: string): void
  (e: 'open-save', messageId: number | string): void
  (e: 'prompt-loaded', prompt: any): void
}>()

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()
const messagesContainer = ref<HTMLElement | null>(null)

const chatStore = useChatStore()
const { messages, currentSessionId, isOptimizing, pendingQueue, sessions } = storeToRefs(chatStore)

const lastEnsuredSessionId = ref<number | null>(null)

const ensureRefPromptCard = async (sid: number) => {
  if (lastEnsuredSessionId.value === sid) return
  
  const session = sessions.value.find(s => s.session_id === sid)
  const refId = session?.ref_prompt_id
  const originPromptId = session?.origin_prompt_id
  
  if (!refId) {
    lastEnsuredSessionId.value = sid
    return
  }

  if (originPromptId && Number(refId) === Number(originPromptId)) {
    lastEnsuredSessionId.value = sid
    return
  }

  const hasAnyPromptRef = messages.value.some((m: any) => m?.type === 'prompt-ref')
  if (hasAnyPromptRef) {
    lastEnsuredSessionId.value = sid
    return
  }

  try {
    const prompt = await getPromptDetail(refId)
    
    const currentUserId = userStore.userInfo?.id
    const isOwnPrompt = String(currentUserId) === String(prompt.author?.id || prompt.user_id)
    if (isOwnPrompt) {
      lastEnsuredSessionId.value = sid
      return
    }
    
    const stillHasPromptRef = messages.value.some((m: any) => m?.type === 'prompt-ref')
    if (stillHasPromptRef) {
      lastEnsuredSessionId.value = sid
      return
    }
    
    emit('prompt-loaded', prompt)
    messages.value.unshift({
      id: Date.now(),
      role: 'ai',
      content: '已加载该提示词上下文，你可以直接使用或让我帮你优化：',
      type: 'prompt-ref',
      promptData: prompt
    } as any)
    lastEnsuredSessionId.value = sid
  } catch (e) {
    console.error('Failed to load referenced prompt detail:', e)
  }
}

watch(currentSessionId, (sid, oldSid) => {
  if (sid !== oldSid) {
    lastEnsuredSessionId.value = null
  }
  if (!sid) return
  ensureRefPromptCard(sid)
}, { immediate: true })

// Scroll State Management
const shouldAutoScroll = ref(true)
const showScrollButton = ref(false)

// Prevent duplicate submissions
const isSending = ref(false)

// Abort controller for stopping generation
const abortController = ref<AbortController | null>(null)

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

const editingMessageId = ref<number | null>(null)

// Prompt Autocomplete Logic
const showPromptMenu = ref(false)
const promptMenuItems = ref<PromptItem[]>([])
const menuFilter = ref('')
const selectedMenuIndex = ref(0)

const filteredPromptMenuItems = computed(() => {
  if (!menuFilter.value) return promptMenuItems.value
  const lower = menuFilter.value.toLowerCase()
  return promptMenuItems.value.filter(p => p.title.toLowerCase().includes(lower))
})

const loadMyPrompts = async () => {
  try {
    const res = await getPrompts({ filter: 'my', pageSize: 100 })
    promptMenuItems.value = res.list || []
  } catch (e) {
    console.error('Failed to load my prompts for autocomplete:', e)
  }
}

// 监听输入，检测 @ 触发菜单
const handleInput = (e: Event) => {
  const target = e.target as HTMLTextAreaElement
  const val = target.value
  const cursorPos = target.selectionStart
  
  // 查找光标前的最后一个 @
  const lastAtPos = val.lastIndexOf('@', cursorPos - 1)
  
  if (lastAtPos !== -1) {
    // 获取 @ 到光标之间的内容作为过滤词
    const query = val.slice(lastAtPos + 1, cursorPos)
    
    // 简单的启发式规则：如果包含换行符，或者距离太远（例如超过20字符），则不认为是触发菜单
    // 这里用户要求流畅，我们假设单行输入 @ 后紧跟关键词
    if (query.includes('\n') || query.length > 20) {
      showPromptMenu.value = false
    } else {
      menuFilter.value = query
      showPromptMenu.value = true
      // 重置选择索引
      selectedMenuIndex.value = 0
    }
  } else {
    showPromptMenu.value = false
  }
  
  nextTick(adjustInputHeight)
}

const selectPrompt = (prompt: PromptItem) => {
  if (!inputRef.value) return
  
  const val = input.value
  const cursorPos = inputRef.value.selectionStart
  const lastAtPos = val.lastIndexOf('@', cursorPos - 1)
  
  if (lastAtPos !== -1) {
    const before = val.slice(0, lastAtPos)
    // 替换 @keyword 为 提示词内容
    // 如果提示词内容很长，直接插入可能会让输入框变得很大，但这是用户期望的
    // "点击后带着内容到对话框" -> 替换 @
    const after = val.slice(cursorPos)
    
    input.value = before + (prompt.content || '') + after
    showPromptMenu.value = false
    
    // 将光标移动到插入内容的末尾
    nextTick(() => {
      if (inputRef.value) {
        inputRef.value.focus()
        const newCursorPos = before.length + (prompt.content || '').length
        inputRef.value.setSelectionRange(newCursorPos, newCursorPos)
        adjustInputHeight()
      }
    })
  }
}

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

const handleOptimizePrompt = (content: string) => {
  input.value = content
  nextTick(() => {
    adjustInputHeight()
    inputRef.value?.focus()
  })
}

const runOptimizeRecord = async (content: string) => {
  if (!content || isOptimizing.value || isSending.value) return
  isSending.value = true
  isOptimizing.value = true
  const aiMsgId = Date.now()
  const aiMsg: any = {
    id: aiMsgId,
    role: 'ai',
    content: '',
    isStreaming: true
  }
  messages.value.push(aiMsg)
  const currentAiMsgIndex = messages.value.length - 1
  abortController.value = new AbortController()
  try {
    await chatStream(
      { query: `@ ${content}`, session_id: currentSessionId.value || undefined },
      (chunk) => {
        pendingQueue.value.push({ msgId: aiMsgId, text: chunk })
        if (!rafId) {
          rafId = requestAnimationFrame(processQueue)
        }
      },
      undefined,
      () => {
        abortController.value = null
        const msg = messages.value[currentAiMsgIndex]
        if (msg) msg.isStreaming = false
        isOptimizing.value = false
        isSending.value = false
        scrollToBottom(true)
      },
      (error) => {
        console.error('Chat optimize error:', error)
        abortController.value = null
        const msg = messages.value[currentAiMsgIndex]
        if (msg) msg.isStreaming = false
        isOptimizing.value = false
        isSending.value = false
      },
      abortController.value.signal
    )
  } catch (e) {
    console.error('Failed to start optimize with @:', e)
    abortController.value = null
    const msg = messages.value[currentAiMsgIndex]
    if (msg) msg.isStreaming = false
    isOptimizing.value = false
    isSending.value = false
  }
}

// Handle Enter key: Enter to send, Shift+Enter for new line
const handleKeydown = (e: KeyboardEvent) => {
  if (showPromptMenu.value && filteredPromptMenuItems.value.length > 0) {
    if (e.key === 'ArrowUp') {
      e.preventDefault()
      selectedMenuIndex.value = (selectedMenuIndex.value - 1 + filteredPromptMenuItems.value.length) % filteredPromptMenuItems.value.length
      return
    }
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      selectedMenuIndex.value = (selectedMenuIndex.value + 1) % filteredPromptMenuItems.value.length
      return
    }
    if (e.key === 'Enter' || e.key === 'Tab') {
      e.preventDefault()
      selectPrompt(filteredPromptMenuItems.value[selectedMenuIndex.value])
      return
    }
    if (e.key === 'Escape') {
      e.preventDefault()
      showPromptMenu.value = false
      return
    }
  }

  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault()
    sendMessage()
  }
  // Shift+Enter will naturally insert a new line
}

// Stop generation
const stopGeneration = () => {
  if (abortController.value) {
    abortController.value.abort()
    abortController.value = null
  }
  isOptimizing.value = false
  isSending.value = false
  
  // Mark the last AI message as no longer streaming
  const lastAiMsg = messages.value.slice().reverse().find(m => m.role === 'ai' && m.isStreaming)
  if (lastAiMsg) {
    lastAiMsg.isStreaming = false
  }
}

// Optimized Queue System
let rafId: number | null = null
const isPageVisible = ref(true)

const handleVisibilityChange = () => {
  isPageVisible.value = !document.hidden
  if (isPageVisible.value && pendingQueue.value.length > 0 && !rafId) {
    rafId = requestAnimationFrame(processQueue)
  }
}

const processQueue = () => {
  if (pendingQueue.value.length === 0) {
    rafId = null
    return
  }

  if (!isPageVisible.value) {
    for (const item of pendingQueue.value) {
      const msg = messages.value.find(m => m.id === item.msgId)
      if (msg) {
        msg.content += item.text
      }
    }
    pendingQueue.value = []
    rafId = null
    scrollToBottom()
    return
  }

  const totalPending = pendingQueue.value.reduce((acc, item) => acc + item.text.length, 0)
  
  const charsPerFrame = totalPending > 1000 ? 100 : (totalPending > 200 ? 20 : 3)
  
  let charsProcessed = 0
  const processedMsgIds = new Set<number>()

  while (charsProcessed < charsPerFrame && pendingQueue.value.length > 0) {
    const item = pendingQueue.value[0]
    const msg = messages.value.find(m => m.id === item.msgId)
    
    if (!msg) {
      pendingQueue.value.shift()
      continue
    }

    const remainingInItem = item.text.length
    const canTake = charsPerFrame - charsProcessed
    const take = Math.min(remainingInItem, canTake)
    
    const chunk = item.text.slice(0, take)
    msg.content += chunk
    
    if (take === remainingInItem) {
      pendingQueue.value.shift()
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
  // Prevent duplicate submissions
  if (!input.value.trim() || isOptimizing.value || isSending.value) return

  if (editingMessageId.value) {
    const editingMsg = messages.value.find(m => m.id === editingMessageId.value)
    if (editingMsg && editingMsg.role === 'user') {
      await handleResendUserMessage(editingMsg)
      return
    }
    editingMessageId.value = null
  }
  
  isSending.value = true
  const prompt = input.value
  input.value = ''
  editingMessageId.value = null
  
  const userMsg = { id: Date.now(), role: 'user', content: prompt }
  messages.value.push(userMsg)
  
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
  
  // Create AbortController for this request
  abortController.value = new AbortController()
  
  // Call real API
  const isFirstMessage = !currentSessionId.value
  const routePromptId = route.query.promptId
  let refPromptId: number | undefined
  if (!currentSessionId.value && routePromptId) {
    const parsed = parseInt(String(routePromptId))
    if (!isNaN(parsed)) refPromptId = parsed
  }

  await chatStream(
    { query: prompt, session_id: currentSessionId.value || undefined, ref_prompt_id: refPromptId },
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
      // Update session ID in store (loadSessions will be called at the end of stream)
      chatStore.currentSessionId = sid

      // 清除临时会话状态
      chatStore.clearTempSession()

      // Update URL
      const query: Record<string, any> = { ...route.query }
      query.session_id = String(sid)
      delete query.promptId
      await router.replace({ query })
    },
    () => {
      // Stream finished
      abortController.value = null
      const checkDone = async () => {
        if (pendingQueue.value.length === 0) {
          isOptimizing.value = false
          isSending.value = false
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
              }
            } catch (e) {
              console.warn('Failed to auto-generate title:', e)
            }
          }
          // Reload sessions to update title and update_time
          await chatStore.loadSessions()

          if (currentSessionId.value) {
            await chatStore.loadSessionHistory(currentSessionId.value)
            await ensureRefPromptCard(currentSessionId.value)
          }
        } else {
          requestAnimationFrame(checkDone)
        }
      }
      checkDone()
    },
    (error) => {
      console.error('Chat error:', error)
      abortController.value = null
      const msg = messages.value[currentAiMsgIndex]
      if (msg) {
        const errorText = '\n[错误: 无法获取响应]'
        pendingQueue.value.push({ msgId: aiMsgId, text: errorText })
      }
      isOptimizing.value = false
      isSending.value = false
      if (msg) msg.isStreaming = false
      scrollToBottom()
    },
    abortController.value.signal
  )
}

const handleEditUserMessage = (msg: any) => {
  editingMessageId.value = msg.id
  input.value = msg.content || ''
  nextTick(() => {
    inputRef.value?.focus()
    adjustInputHeight()
  })
}

const handleResendUserMessage = async (msg: any) => {
  if (isOptimizing.value || isSending.value) return

  const candidate = (editingMessageId.value === msg.id ? input.value : msg.content) || ''
  const content = candidate.trim()
  if (!content) return

  if (!currentSessionId.value) {
    input.value = content
    await nextTick()
    await sendMessage()
    return
  }

  const sid = currentSessionId.value
  if (!sid) return

  isSending.value = true
  isOptimizing.value = true

  const idx = messages.value.findIndex(m => m.id === msg.id)
  if (idx !== -1) {
    messages.value[idx].content = content
    messages.value.splice(idx + 1)
  }

  editingMessageId.value = null
  input.value = ''

  const aiMsgId = Date.now()
  const aiMsg: any = {
    id: aiMsgId,
    role: 'ai',
    content: '',
    isStreaming: true
  }
  messages.value.push(aiMsg)
  const currentAiMsgIndex = messages.value.length - 1

  // Create AbortController for this request
  abortController.value = new AbortController()

  await regenerateChatStream(
    { session_id: sid, message_id: msg.id, query: content },
    (chunk) => {
      pendingQueue.value.push({ msgId: aiMsgId, text: chunk })
      if (!rafId) {
        rafId = requestAnimationFrame(processQueue)
      }
    },
    () => {
      abortController.value = null
      const checkDone = async () => {
        if (pendingQueue.value.length === 0) {
          isOptimizing.value = false
          isSending.value = false
          const m = messages.value[currentAiMsgIndex]
          if (m) m.isStreaming = false
          await chatStore.loadSessions()
          await chatStore.loadSessionHistory(sid)
          await ensureRefPromptCard(sid)
        } else {
          requestAnimationFrame(checkDone)
        }
      }
      checkDone()
    },
    (error) => {
      console.error('Failed to regenerate message:', error)
      abortController.value = null
      isOptimizing.value = false
      isSending.value = false
      const m = messages.value[currentAiMsgIndex]
      if (m) m.isStreaming = false
      chatStore.loadSessionHistory(sid)
      ensureRefPromptCard(sid)
    },
    abortController.value.signal
  )
}

defineExpose({
  handleOptimizePrompt
})

onMounted(async () => {
  document.addEventListener('visibilitychange', handleVisibilityChange)
  await chatStore.loadSessions()
  
  // Load prompts for autocomplete
  loadMyPrompts()
  
  // Priority 1: Check for session_id (Existing Chat)
  const routeSessionId = route.query.session_id
  if (routeSessionId) {
    const sid = parseInt(String(routeSessionId))
    if (!isNaN(sid)) {
      chatStore.currentSessionId = sid
      await chatStore.loadSessionHistory(sid)
      await ensureRefPromptCard(sid)
      if (route.query.promptId) {
        const query: Record<string, any> = { ...route.query }
        delete query.promptId
        await router.replace({ query })
      }
    }
    return
  }

  // Priority 2: Check for promptId (New Chat from Prompt)
  const promptId = route.query.promptId
  if (promptId) {
    const id = parseInt(promptId as string)
    if (!isNaN(id)) {
      try {
        // 尝试从 history.state 获取预加载数据，避免重复请求
        const state = history.state as { initialPrompt?: any } | null
        let prompt = null
        
        if (state?.initialPrompt && String(state.initialPrompt.id) === String(id)) {
          prompt = state.initialPrompt
        } else {
          prompt = await getPromptDetail(id)
        }
        
        if (!prompt) return

        // 通知父组件已加载提示词
        emit('prompt-loaded', prompt)
        
        // 检查是否是自己的提示词，如果是且存在关联会话，则跳转到该会话
        const currentUserId = userStore.userInfo?.id
        const isOwnPrompt = String(currentUserId) === String(prompt.author?.id || prompt.user_id)
        
        if (isOwnPrompt) {
          // 查找是否存在关联的会话
          const sessionResult = await getSessionByPromptId(id)
          if (sessionResult.found && sessionResult.session) {
            // 存在关联会话，直接跳转到该会话
            const sid = sessionResult.session.session_id
            chatStore.currentSessionId = sid
            await chatStore.loadSessionHistory(sid)
            
            // 更新 URL，移除 promptId，添加 session_id
            const query: Record<string, any> = { ...route.query }
            delete query.promptId
            query.session_id = String(sid)
            await router.replace({ query })
            return
          }
          
          // 自己的提示词但没有会话记录，创建草稿会话，显示普通文本消息
          chatStore.openDraftSession()
          chatStore.draftTitle = prompt.title || '新对话'
          
          // 设置临时会话状态
          chatStore.setTempSession({
            id: `temp-own-${prompt.id}`,
            title: prompt.title,
            promptId: prompt.id,
            isOwnPrompt: true,
            promptData: prompt
          })
          
          // 显示普通文本消息，不加"引用内容"特效
          messages.value.push({
            id: Date.now(),
            role: 'ai',
            content: prompt.content || '',
            type: 'text'
          })
          return
        }
        
        // 别人的提示词，创建新的草稿会话，显示"引用内容"卡片
        chatStore.openDraftSession()
        chatStore.draftTitle = prompt.title || '新对话'
        
        // 设置临时会话状态
        chatStore.setTempSession({
          id: `temp-ref-${prompt.id}`,
          title: prompt.title,
          promptId: prompt.id,
          isOwnPrompt: false,
          promptData: prompt
        })
        
        messages.value.push({
          id: Date.now(),
          role: 'ai',
          content: '已加载该提示词上下文，你可以直接使用或让我帮你优化：',
          type: 'prompt-ref',
          promptData: prompt
        })
      } catch (e) {
        console.error('Failed to load prompt detail:', e)
      }
    }
    return
  }
  
  // If no session ID and no prompt ID, check if we already have messages (from store)
  // If not, reset to welcome. This prevents double welcome if store already has it.
  if (!currentSessionId.value && messages.value.length === 0) {
    chatStore.resetToWelcome()
  }
})

onUnmounted(() => {
  document.removeEventListener('visibilitychange', handleVisibilityChange)
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
              <Sparkles :size="18" />
            </div>
            <div class="chat-message-content">
              <div class="chat-bubble">
                <div v-if="msg.type === 'prompt-ref' && msg.promptData">
                  <PromptReferenceCard 
                    :prompt="msg.promptData" 
                    compact
                  />
                  <div class="message-actions" v-if="!msg.isStreaming">
                    <CopyButton :text="msg.promptData.content" />
                    <button class="action-btn-pill" @click="emit('open-test', msg.promptData.content)" title="在测试台中打开">
                      <FlaskConical :size="14" />
                      <span>测试</span>
                    </button>
                    <button class="action-btn-pill" @click="emit('switch-expert', msg.promptData.content || msg.content, msg.id)" title="切换到专家模式编辑">
                      <Code2 :size="14" />
                      <span>专家模式</span>
                    </button>
                    <button class="action-btn-pill" type="button" title="保存" @click="emit('open-save', msg.id)">
                      <Save :size="14" />
                      <span>保存</span>
                    </button>
                    <button class="action-btn-pill" type="button" title="优化此内容" @click="runOptimizeRecord(msg.promptData.content || msg.content)" :disabled="isOptimizing || isSending">
                      <Sparkles :size="14" />
                      <span>优化</span>
                    </button>
                  </div>
                </div>

                <div v-else-if="msg.role === 'ai'" class="ai-message-wrapper">
                  <!-- 已保存提示词标记 -->
                  <div v-if="msg.type === 'saved'" class="saved-prompt-badge">
                    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                      <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
                      <polyline points="14 2 14 8 20 8"></polyline>
                      <line x1="16" y1="13" x2="8" y2="13"></line>
                      <line x1="16" y1="17" x2="8" y2="17"></line>
                    </svg>
                    <span>已保存的提示词</span>
                  </div>
                  <AiContentRenderer
                    :content="msg.content"
                    :is-streaming="msg.isStreaming"
                    :show-copy="msg.type !== 'welcome'"
                  >
                    <template #actions v-if="!msg.isStreaming && msg.type !== 'welcome'">
                      <button class="action-btn-pill" @click="emit('open-test', msg.content)" title="在测试台中打开">
                        <FlaskConical :size="14" />
                        <span>测试</span>
                      </button>
                      <button class="action-btn-pill" @click="emit('switch-expert', msg.content, msg.id)" title="切换到专家模式编辑">
                        <Code2 :size="14" />
                        <span>专家模式</span>
                      </button>
                      <button class="action-btn-pill" type="button" title="保存" @click="emit('open-save', msg.id)">
                        <Save :size="14" />
                        <span>保存</span>
                      </button>
                      <button class="action-btn-pill" type="button" title="优化此内容" @click="runOptimizeRecord(msg.content)" :disabled="isOptimizing || isSending">
                        <Sparkles :size="14" />
                        <span>优化</span>
                      </button>
                    </template>
                  </AiContentRenderer>
                </div>

                <div v-else-if="msg.role !== 'ai'" style="white-space: pre-wrap;">{{ msg.content }}</div>
              </div>

              <div v-if="msg.role === 'user' && msg.type !== 'welcome'" class="message-actions user-actions">
                <button class="action-btn-pill" type="button" title="编辑这条消息" @click="handleEditUserMessage(msg)" :disabled="isOptimizing || isSending">
                  <Pencil :size="14" />
                  <span>编辑</span>
                </button>
                <button class="action-btn-pill" type="button" title="从这条消息开始重新生成" @click="handleResendUserMessage(msg)" :disabled="isOptimizing || isSending">
                  <RotateCw :size="14" />
                  <span>重新发送</span>
                </button>
              </div>
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
            <!-- Prompt Autocomplete Menu -->
            <div v-if="showPromptMenu && filteredPromptMenuItems.length > 0" class="prompt-menu">
              <div 
                v-for="(item, index) in filteredPromptMenuItems" 
                :key="item.id"
                class="prompt-menu-item"
                :class="{ active: index === selectedMenuIndex }"
                @click="selectPrompt(item)"
                @mousedown.prevent
              >
                <div class="prompt-menu-icon">
                  <Sparkles :size="14" />
                </div>
                <div class="prompt-menu-info">
                  <div class="prompt-menu-title">{{ item.title }}</div>
                  <div class="prompt-menu-preview">{{ item.content?.slice(0, 30) }}...</div>
                </div>
              </div>
            </div>

            <textarea 
              ref="inputRef"
              class="chat-input" 
              v-model="input"
              placeholder="描述你的需求，或使用 @ 引用提示词...&#10;Enter 发送，Shift+Enter 换行"
              @keydown="handleKeydown"
              @input="handleInput"
              @blur="() => setTimeout(() => showPromptMenu = false, 200)"
            ></textarea>
            
            <div class="chat-input-actions">
              <button class="action-btn" title="导入/导出" type="button">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"></path>
                  <polyline points="16 6 12 2 8 6"></polyline>
                  <line x1="12" y1="2" x2="12" y2="15"></line>
                </svg>
              </button>
              <button 
                v-if="isOptimizing" 
                class="chat-stop-btn" 
                type="button" 
                @click="stopGeneration" 
                title="停止生成"
              >
                <Square :size="16" fill="currentColor" />
              </button>
              <button 
                v-else
                class="chat-send-btn" 
                type="button" 
                @click="sendMessage" 
                :disabled="!input.trim()"
              >
                <SendHorizontal :size="16" />
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>


<style scoped>
.chat-input-wrapper {
  position: relative;
  /* ... existing styles if any ... */
}

.prompt-menu {
  position: absolute;
  bottom: 100%;
  left: 0;
  width: 100%;
  max-height: 240px;
  overflow-y: auto;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  box-shadow: 0 -4px 12px rgba(0, 0, 0, 0.1);
  margin-bottom: 8px;
  z-index: 100;
  padding: 4px;
}

.prompt-menu-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  cursor: pointer;
  border-radius: 6px;
  transition: background 0.2s;
}

.prompt-menu-item:hover, .prompt-menu-item.active {
  background: var(--bg-primary);
}

.prompt-menu-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  background: var(--bg-secondary);
  border-radius: 4px;
  color: var(--primary);
}

.prompt-menu-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
  flex: 1;
}

.prompt-menu-title {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-primary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.prompt-menu-preview {
  font-size: 12px;
  color: var(--text-secondary);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.message-actions {
  margin-top: 12px;
  display: flex;
  justify-content: flex-start;
  gap: 8px;
}

.message-actions.user-actions {
  justify-content: flex-end;
}

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

/* 已保存提示词标记 */
.ai-message-wrapper {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.saved-prompt-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: linear-gradient(135deg, #10b981 0%, #059669 100%);
  color: white;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  width: fit-content;
  box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
}

.saved-prompt-badge svg {
  stroke: white;
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

.chat-message-content {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  min-width: 0;
}

.chat-message.user .chat-message-content {
  align-items: flex-end;
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
  overflow-wrap: break-word;
  word-wrap: break-word;
  min-width: 0; /* Ensure text truncation/wrapping works */
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
  padding: 24px 20px 32px;
  background: linear-gradient(to top, var(--bg-primary) 60%, transparent);
  display: flex;
  justify-content: center;
  width: 100%;
  position: sticky;
  bottom: 0;
  z-index: 5;
}

.chat-input-wrapper {
  position: relative;
  background: var(--bg-surface);
  border-radius: 20px;
  padding: 8px;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  border: 1.5px solid var(--gray-200);
  width: 100%;
  max-width: 850px;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
}

.chat-input-wrapper:focus-within {
  background: var(--bg-surface);
  box-shadow: 0 8px 30px rgba(59, 130, 246, 0.12);
  border-color: var(--primary);
  transform: translateY(-2px);
}

.chat-input {
  width: 100%;
  min-height: 52px;
  max-height: 200px;
  padding: 12px 110px 12px 16px;
  border: none;
  background: transparent;
  resize: none;
  font-size: 15px;
  color: var(--text-primary);
  line-height: 1.6;
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

.chat-stop-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: #ef4444;
  color: white;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
  animation: pulse 1.5s ease-in-out infinite;
}

.chat-stop-btn:hover {
  transform: scale(1.05);
  background: #dc2626;
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

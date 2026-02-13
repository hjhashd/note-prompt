import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { 
  listChatSessions, 
  getChatSessionMessages, 
  renameChatSession, 
  deleteChatSession, 
  chatStream,
  optimizeStream
} from '@/api/lyf-ai'
import type { ChatMessageItem, ChatSessionItem } from '@/api/lyf-ai'
import type { PromptItem } from '@/types/prompt'

export interface Message {
  id: number
  role: string
  content: string
  isStreaming?: boolean
  type?: 'text' | 'prompt-ref' | 'welcome'
  promptData?: PromptItem
}

export const useChatStore = defineStore('chat', () => {
  // State
  const sessions = ref<ChatSessionItem[]>([])
  const sessionsLoading = ref(false)
  const currentSessionId = ref<number | null>(null)
  const draftTitle = ref<string>('')
  const messages = ref<Message[]>([])
  const isOptimizing = ref(false)
  const pendingQueue = ref<{ msgId: number, text: string }[]>([])
  
  // Computed
  const currentSession = computed(() => {
    if (!currentSessionId.value) return null
    return sessions.value.find(s => s.session_id === currentSessionId.value) || null
  })
  
  const currentSessionTitle = computed(() => {
    if (currentSessionId.value && currentSession.value) {
      return currentSession.value.title
    }
    return draftTitle.value || '新对话'
  })

  // Actions
  const resetToWelcome = () => {
    // Only reset if not already welcome message
    const isWelcome = messages.value.length === 1 && messages.value[0].type === 'welcome'
    if (isWelcome) {
      draftTitle.value = ''
      return
    }

    draftTitle.value = ''
    messages.value = [
      { 
        id: 1, 
        role: 'ai', 
        content: '你好！我是提示词助手。你可以：\n• 描述你的需求，我会帮你构建提示词\n• 使用 @ 引用已有提示词\n• 使用 @ 提示词优化',
        type: 'welcome'
      }
    ]
  }

  const loadSessions = async () => {
    sessionsLoading.value = true
    try {
      // 加载所有会话（不传status参数获取所有）
      const allSessions = await listChatSessions(100)
      // 按更新时间排序
      allSessions.sort((a, b) => {
        const timeA = a.update_time ? new Date(a.update_time).getTime() : 0
        const timeB = b.update_time ? new Date(b.update_time).getTime() : 0
        return timeB - timeA
      })
      sessions.value = allSessions
    } catch (e) {
      console.error('Failed to load sessions:', e)
    } finally {
      sessionsLoading.value = false
    }
  }

  const loadSessionHistory = async (sessionId: number) => {
    try {
      const history = await getChatSessionMessages(sessionId, 200)

      const toPromptItem = (payload: any): PromptItem => ({
        id: Number(payload?.id || 0),
        title: String(payload?.title || ''),
        description: payload?.description ? String(payload.description) : undefined,
        content: payload?.content ? String(payload.content) : '',
        tags: [],
        author: { name: '' },
        stats: { views: 0, likes: 0 },
        updatedAt: '',
        createdAt: undefined,
        isLiked: false,
        isFavorited: false
      })

      const parsePromptRef = (raw: string | undefined | null) => {
        if (!raw) return null
        const prefix = '__PROMPT_REF__'
        if (!raw.startsWith(prefix)) return null
        const body = raw.slice(prefix.length)
        const newlineIdx = body.indexOf('\n')
        const jsonPart = (newlineIdx === -1 ? body : body.slice(0, newlineIdx)).trim()
        const rest = newlineIdx === -1 ? '' : body.slice(newlineIdx).replace(/^\n+/, '')
        try {
          const payload = JSON.parse(jsonPart)
          return { prompt: toPromptItem(payload), rest }
        } catch {
          return null
        }
      }

      const mapped: Message[] = history
        .filter(m => m.role !== 'system')
        .map((m: ChatMessageItem) => {
          const parsed = parsePromptRef(m.content)
          if (parsed) {
            return {
              id: m.id,
              role: 'ai',
              content: parsed.rest || parsed.prompt.content || '',
              type: 'prompt-ref',
              promptData: parsed.prompt
            }
          }
          return {
            id: m.id,
            role: m.role === 'assistant' ? 'ai' : 'user',
            content: m.content,
            type: 'text'
          }
        })
      
      messages.value = mapped.length > 0 ? mapped : []
      if (messages.value.length === 0) {
        resetToWelcome()
      }
    } catch (e) {
      console.error('Failed to load history:', e)
      throw e
    }
  }

  const switchToSession = async (sessionId: number) => {
    currentSessionId.value = sessionId
    await loadSessionHistory(sessionId)
  }

  const openDraftSession = () => {
    currentSessionId.value = null
    resetToWelcome()
  }

  const createNewSession = async () => {
    openDraftSession()
  }

  const renameSession = async (sessionId: number, newTitle: string) => {
    try {
      await renameChatSession(sessionId, newTitle)
      await loadSessions()
    } catch (e) {
      console.error('Failed to rename session:', e)
      throw e
    }
  }

  const removeSession = async (sessionId: number, deletePrompt = true) => {
    try {
      const result = await deleteChatSession(sessionId, deletePrompt)
      if (currentSessionId.value === sessionId) {
        openDraftSession()
      }
      await loadSessions()
      return result
    } catch (e) {
      console.error('Failed to delete session:', e)
      throw e
    }
  }

  const updateSessionPromptId = (sessionId: number, promptId: number) => {
    const session = sessions.value.find(s => s.session_id === sessionId)
    if (session) {
      session.origin_prompt_id = promptId
    }
  }

  return {
    sessions,
    sessionsLoading,
    currentSessionId,
    draftTitle,
    currentSession,
    currentSessionTitle,
    messages,
    isOptimizing,
    pendingQueue,
    loadSessions,
    loadSessionHistory,
    switchToSession,
    openDraftSession,
    createNewSession,
    renameSession,
    removeSession,
    resetToWelcome,
    updateSessionPromptId
  }
})

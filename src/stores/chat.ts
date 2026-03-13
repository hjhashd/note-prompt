import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import {
  listChatSessions,
  getChatSessionMessages,
  renameChatSession,
  deleteChatSession
} from '@/api/lyf-ai'
import type { ChatMessageItem, ChatSessionItem } from '@/api/lyf-ai'

export interface Message {
  id: number
  role: string
  content: string
  isStreaming?: boolean
  type?: 'text' | 'welcome' | 'saved'
}

export interface TempSession {
  id: string
  title: string
  promptId: number
  isOwnPrompt: boolean
  promptData?: any
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
  const tempSession = ref<TempSession | null>(null)
  const generatingTitleSessionIds = ref<Set<number>>(new Set())
  
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
      const response = await getChatSessionMessages(sessionId, 200)
      const { session, messages: historyMessages } = response

      // 提取 __PROMPT_REF__ 标记后的实际内容
      const extractContent = (raw: string): string => {
        const prefix = '__PROMPT_REF__'
        if (!raw.startsWith(prefix)) return raw
        const body = raw.slice(prefix.length)
        const newlineIdx = body.indexOf('\n')
        return newlineIdx === -1 ? '' : body.slice(newlineIdx + 1)
      }

      const finalContent = session?.final_content

      const mapped: Message[] = historyMessages
        .filter(m => m.role !== 'system')
        .map((m: ChatMessageItem) => {
          const content = extractContent(m.content)
          // 如果消息内容与会话的 final_content 匹配，标记为 saved 类型
          const isSaved = finalContent && content.trim() === finalContent.trim()
          return {
            id: m.id,
            role: m.role === 'assistant' ? 'ai' : 'user',
            content,
            type: isSaved ? 'saved' : 'text'
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
      // Update local state instead of full reload to avoid flickering
      const session = sessions.value.find(s => s.session_id === sessionId)
      if (session) {
        session.title = newTitle
      } else {
        await loadSessions()
      }
    } catch (e) {
      console.error('Failed to rename session:', e)
      throw e
    }
  }

  const updateSessionTitle = (sessionId: number, newTitle: string) => {
    const session = sessions.value.find(s => s.session_id === sessionId)
    if (session) {
      session.title = newTitle
    }
  }

  const addSession = (session: ChatSessionItem) => {
    // Add to top of list if not exists
    const exists = sessions.value.some(s => s.session_id === session.session_id)
    if (!exists) {
      sessions.value.unshift(session)
    }
  }
  
  const setSessionGeneratingTitle = (sessionId: number, isGenerating: boolean) => {
    if (isGenerating) {
      generatingTitleSessionIds.value.add(sessionId)
    } else {
      generatingTitleSessionIds.value.delete(sessionId)
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

  const setTempSession = (data: TempSession | null) => {
    tempSession.value = data
  }

  const clearTempSession = () => {
    tempSession.value = null
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
    tempSession,
    generatingTitleSessionIds,
    loadSessions,
    loadSessionHistory,
    switchToSession,
    openDraftSession,
    createNewSession,
    renameSession,
    updateSessionTitle,
    addSession,
    setSessionGeneratingTitle,
    removeSession,
    resetToWelcome,
    updateSessionPromptId,
    setTempSession,
    clearTempSession
  }
})

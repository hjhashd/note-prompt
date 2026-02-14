import { useUserStore } from '@/stores/user'

/**
 * LYF AI 模块接口服务
 */

export interface ChatRequest {
  query: string
  user_id?: string
  session_id?: number
  ref_prompt_id?: number
}

export interface OptimizeRequest {
  raw_prompt: string
  target_scene: string
}

export interface TestRequest {
  system_prompt: string
  user_input: string
}

export interface RegenerateRequest {
  session_id: number
  message_id: number
  query: string
}

/**
 * 通用流式请求处理函数
 */
async function handleStreamRequest(
  url: string,
  params: any,
  onMessage: (content: string) => void,
  onMeta?: (meta: any) => void,
  onDone?: () => void,
  onError?: (error: any) => void,
  signal?: AbortSignal
) {
  const userStore = useUserStore()
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userStore.token}`
      },
      body: JSON.stringify(params),
      signal
    })

    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`)
    }

    if (!response.body) {
      throw new Error('Response body is null')
    }

    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    
    let buffer = ''

    while (true) {
      const { done, value } = await reader.read()
      if (done) break

      const chunk = decoder.decode(value, { stream: true })
      buffer += chunk
      
      const lines = buffer.split('\n\n')
      buffer = lines.pop() || ''

      for (const line of lines) {
        if (line.startsWith('data: ')) {
          const data = line.slice(6)
          if (data === '[DONE]') {
            if (onDone) onDone()
            return
          }
          
          try {
            const parsed = JSON.parse(data)
            if (parsed.meta && onMeta) {
              onMeta(parsed.meta)
            }
            if (parsed.content) {
              onMessage(parsed.content)
            }
          } catch (e) {
            console.warn('Failed to parse SSE data:', data)
          }
        }
      }
    }
  } catch (error) {
    // Check if the error is due to abort
    if (error instanceof Error && error.name === 'AbortError') {
      console.log('Stream aborted by user')
      if (onDone) onDone()
      return
    }
    if (onError) onError(error)
    else console.error('Stream error:', error)
  }
}

/**
 * 流式对话接口
 */
export async function chatStream(
  params: ChatRequest,
  onMessage: (content: string) => void,
  onMeta?: (meta: any) => void,
  onDone?: () => void,
  onError?: (error: any) => void,
  signal?: AbortSignal
) {
  return handleStreamRequest(
    '/api/python/ai/chat/v2/prompt_chat/stream',
    params,
    onMessage,
    onMeta,
    onDone,
    onError,
    signal
  )
}

/**
 * 提示词优化流式接口
 */
export async function optimizeStream(
  params: OptimizeRequest,
  onMessage: (content: string) => void,
  onDone?: () => void,
  onError?: (error: any) => void
) {
  return handleStreamRequest(
    '/api/python/ai/optimize/prompt_optimize/stream',
    params,
    onMessage,
    undefined,
    onDone,
    onError
  )
}

/**
 * 提示词测试流式接口
 */
export async function testStream(
  params: TestRequest,
  onMessage: (content: string) => void,
  onDone?: () => void,
  onError?: (error: any) => void
) {
  return handleStreamRequest(
    '/api/python/ai/test/prompt_test/stream',
    params,
    onMessage,
    undefined,
    onDone,
    onError
  )
}

export async function regenerateChatStream(
  params: RegenerateRequest,
  onMessage: (content: string) => void,
  onDone?: () => void,
  onError?: (error: any) => void,
  signal?: AbortSignal
) {
  return handleStreamRequest(
    `/api/python/ai/chat/v2/sessions/${params.session_id}/messages/${params.message_id}/regenerate/stream`,
    { query: params.query },
    onMessage,
    undefined,
    onDone,
    onError,
    signal
  )
}

/**
 * 针对指定的 AI 消息进行“就地优化重写”（不新增消息），生成完成后更新该消息的 content
 */
export async function optimizeMessageInplaceStream(
  sessionId: number,
  messageId: number,
  onMessage: (content: string) => void,
  onDone?: () => void,
  onError?: (error: any) => void,
  signal?: AbortSignal
) {
  return handleStreamRequest(
    `/api/python/ai/chat/v2/sessions/${sessionId}/messages/${messageId}/optimize-inplace/stream`,
    {},
    onMessage,
    undefined,
    onDone,
    onError,
    signal
  )
}

async function handleJsonRequest<TResponse = any>(
  url: string,
  options: RequestInit
): Promise<TResponse> {
  const userStore = useUserStore()
  const resp = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${userStore.token}`,
      ...(options.headers || {})
    }
  })

  if (!resp.ok) {
    const text = await resp.text().catch(() => '')
    throw new Error(`HTTP error! status: ${resp.status} ${text}`)
  }

  return resp.json()
}

export interface ChatSessionItem {
  session_id: number
  title: string
  create_time?: string
  update_time?: string
  status?: string
  origin_prompt_id?: number
  ref_prompt_id?: number
  final_content?: string
}

export interface ChatMessageItem {
  id: number
  role: 'user' | 'assistant' | 'system'
  content: string
  create_time?: string
}

export interface ChatSessionMessagesResponse {
  session: ChatSessionItem
  messages: ChatMessageItem[]
}

export async function createChatSession(title?: string) {
  return handleJsonRequest<ChatSessionItem>('/api/python/ai/chat/v2/sessions', {
    method: 'POST',
    body: JSON.stringify({ title })
  })
}

export async function listChatSessions(limit = 50, status?: string) {
  const url = new URL('/api/python/ai/chat/v2/sessions', window.location.origin)
  url.searchParams.set('limit', String(limit))
  if (status) url.searchParams.set('status', status)
  return handleJsonRequest<ChatSessionItem[]>(url.pathname + url.search, { method: 'GET' })
}

export async function getSessionByPromptId(promptId: number) {
  return handleJsonRequest<{ 
    found: boolean
    session: ChatSessionItem | null 
  }>(`/api/python/ai/chat/v2/sessions/by-prompt/${promptId}`, { method: 'GET' })
}

export async function getChatSessionMessages(sessionId: number, limit = 200) {
  const url = new URL(`/api/python/ai/chat/v2/sessions/${sessionId}/messages`, window.location.origin)
  url.searchParams.set('limit', String(limit))
  return handleJsonRequest<ChatSessionMessagesResponse>(url.pathname + url.search, { method: 'GET' })
}

export async function forkChatSession(sessionId: number, uptoMessageId: number, title?: string) {
  return handleJsonRequest<ChatSessionItem>(`/api/python/ai/chat/v2/sessions/${sessionId}/fork`, {
    method: 'POST',
    body: JSON.stringify({ upto_message_id: uptoMessageId, title })
  })
}

export async function renameChatSession(sessionId: number, title: string) {
  return handleJsonRequest<ChatSessionItem>(`/api/python/ai/chat/v2/sessions/${sessionId}`, {
    method: 'PATCH',
    body: JSON.stringify({ title })
  })
}

export async function deleteChatSession(sessionId: number, deletePrompt = true) {
  return handleJsonRequest<{ 
    ok: boolean, 
    session_id: number, 
    deleted_prompt?: boolean,session_id?: number 
  }>(`/api/python/ai/chat/v2/sessions/${sessionId}?delete_prompt=${deletePrompt}`, {
    method: 'DELETE'
  })
}

export async function autoGenerateTitle(sessionId: number, contextText: string) {
  return handleJsonRequest<{ 
    ok: boolean, 
    session_id: number, 
    new_title: string 
  }>(`/api/python/ai/title/sessions/${sessionId}/auto-title`, {
    method: 'POST',
    body: JSON.stringify({ context_text: contextText })
  })
}

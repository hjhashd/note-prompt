import { useUserStore } from '@/stores/user'

/**
 * LYF AI 模块接口服务
 */

export interface ChatRequest {
  query: string
  user_id?: string
}

export interface OptimizeRequest {
  raw_prompt: string
  target_scene: string
}

export interface TestRequest {
  system_prompt: string
  user_input: string
}

/**
 * 通用流式请求处理函数
 */
async function handleStreamRequest(
  url: string,
  params: any,
  onMessage: (content: string) => void,
  onDone?: () => void,
  onError?: (error: any) => void
) {
  const userStore = useUserStore()
  
  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${userStore.token}`
      },
      body: JSON.stringify(params)
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
  onDone?: () => void,
  onError?: (error: any) => void
) {
  return handleStreamRequest(
    '/api/python/ai/chat/prompt_chat/stream',
    params,
    onMessage,
    onDone,
    onError
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
    onDone,
    onError
  )
}

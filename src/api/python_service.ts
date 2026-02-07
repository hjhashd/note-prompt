import request from '@/utils/request'

/**
 * Python 后端服务示例
 * 注意：Python 后端接口不带 /api 前缀，代理会自动移除 /api/python
 */

export function getPythonStatus() {
  return request<any, any>({
    url: '/python/status', // 实际请求会变为 /api/python/status -> 代理重写为 /status
    method: 'get'
  })
}

/**
 * 示例：调用 Python 后端的 AI 处理接口
 */
export function processWithAI(data: any) {
  return request<any, any>({
    url: '/python/v1/ai/process', // 实际请求会变为 /api/python/v1/ai/process -> 代理重写为 /v1/ai/process
    method: 'post',
    data
  })
}

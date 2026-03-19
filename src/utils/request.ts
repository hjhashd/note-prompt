import axios, { type AxiosInstance, type AxiosResponse } from 'axios'
import { useUserStore } from '@/stores/user'
import { useToast } from '@/composables/useToast'

// 创建 Axios 实例
// 智能策略：不设置绝对 baseURL，使用相对路径，自动适配当前访问的域名/IP/端口
const service: AxiosInstance = axios.create({
  baseURL: '/api', // 统一使用 /api 前缀，配合 proxy/nginx 转发
  timeout: 10000,
  paramsSerializer: {
    indexes: null // 序列化数组为 tagId=1&tagId=2 而不是 tagId[]=1
  }
})

// 请求拦截器
service.interceptors.request.use(
  (config) => {
    const userStore = useUserStore()
    if (userStore.token) {
      config.headers['Authorization'] = `Bearer ${userStore.token}`
    }
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

// 响应拦截器
service.interceptors.response.use(
  (response: AxiosResponse) => {
    // 检查响应数据是否为对象，防止返回 HTML (如 404/500 页) 导致解析错误
    if (!response.data || typeof response.data !== 'object') {
      console.error('[API Error] Invalid JSON response:', response.data)
      return Promise.reject(new Error('Invalid JSON response'))
    }

    const { code, data, message } = response.data

    // 业务逻辑成功判断（0 为成功，200 为新服务成功码）
    if (code === 0 || code === 200) {
      // 直接解析并返回 response.data.data
      return data
    }

    // 统一处理业务错误
    console.error(`[API Error] Code: ${code}, Message: ${message || 'Unknown Error'}`)
    const { toast } = useToast()
    toast(message || `API Error ${code}`, 'error')
    return Promise.reject(new Error(message || `API Error ${code}`))
  },
  (error) => {
    const { toast } = useToast()
    // 处理 HTTP 状态码错误
    const status = error.response?.status
    if (status === 401 || status === 403) {
      const userStore = useUserStore()
      userStore.clearToken()
      toast('登录已过期，请重新登录', 'warning')
      // 延迟跳转，让用户看到提示
      setTimeout(() => {
        window.location.href = '/login'
      }, 1500)
    } else {
      // 根据错误类型显示友好的提示信息
      let errorMsg = '网络错误，请稍后重试'
      if (status === 400) {
        errorMsg = '请求参数有误，请检查后重试'
      } else if (status === 404) {
        errorMsg = '请求的资源不存在'
      } else if (status === 500) {
        errorMsg = '服务器繁忙，请稍后再试'
      } else if (!navigator.onLine) {
        errorMsg = '网络连接失败，请检查网络设置'
      }
      toast(errorMsg, 'error')
    }
    return Promise.reject(error)
  }
)

export default service

import axios, { type AxiosInstance, type AxiosResponse } from 'axios'
import { useUserStore } from '@/stores/user'

// 创建 Axios 实例
const service: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/', // 默认由 Vite 或 Nginx 代理
  timeout: 10000,
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
    const { code, data, message } = response.data

    // 业务逻辑成功判断（假设 200 为成功）
    if (code === 200) {
      // 直接解析并返回 response.data.data
      return data
    }

    // 统一处理业务错误
    console.error(`[API Error] ${message || 'Unknown Error'}`)
    alert(message || '请求失败')
    return Promise.reject(new Error(message || 'Error'))
  },
  (error) => {
    // 处理 HTTP 状态码错误
    if (error.response?.status === 401) {
      const userStore = useUserStore()
      userStore.clearToken()
      alert('登录已过期，请重新进入')
    } else {
      alert(error.message || '网络错误')
    }
    return Promise.reject(error)
  }
)

export default service

import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { login as loginApi } from '@/api/auth'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('auth_token') || '')
  const userInfo = ref(JSON.parse(localStorage.getItem('user_info') || '{}'))

  const isAuthenticated = computed(() => !!token.value)

  function setToken(newToken: string) {
    token.value = newToken
    if (newToken) {
      localStorage.setItem('auth_token', newToken)
    } else {
      localStorage.removeItem('auth_token')
    }
  }

  function setUserInfo(info: any) {
    userInfo.value = info
    if (info) {
      localStorage.setItem('user_info', JSON.stringify(info))
    } else {
      localStorage.removeItem('user_info')
    }
  }

  function clearToken() {
    setToken('')
    setUserInfo({})
  }

  async function login(loginForm: any) {
    try {
      const data = await loginApi(loginForm)
      // 根据 API_SPECIFICATION: data 结构为 { token: "...", userInfo: { ... } }
      if (data.token) {
        setToken(data.token)
      }
      if (data.userInfo) {
        setUserInfo(data.userInfo)
      }
      return data
    } catch (error) {
      throw error
    }
  }

  return { 
    token, 
    userInfo,
    isAuthenticated, 
    setToken, 
    setUserInfo,
    clearToken,
    login
  }
})

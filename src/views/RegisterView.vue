<template>
  <div class="register-container min-h-screen flex items-center justify-center p-4">
    <div class="bg-decoration">
      <div class="circle circle-1"></div>
      <div class="circle circle-2"></div>
      <div class="circle circle-3"></div>
    </div>

    <div class="register-card max-w-md w-full space-y-8 p-10 rounded-3xl shadow-2xl backdrop-blur-xl border border-white/20">
      <div class="text-center">
        <div class="logo-wrapper mb-6">
          <div class="logo-icon">
            <svg viewBox="0 0 80 80" fill="none" xmlns="http://www.w3.org/2000/svg" class="w-12 h-12 mx-auto">
              <circle cx="40" cy="40" r="37" fill="#3B82F6"/>
              <path d="M25 25L41 40L25 55" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M47 48H58" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
              <circle cx="51" cy="32" r="2.5" fill="#FFFFFF"/>
            </svg>
          </div>
        </div>
        <h2 class="text-4xl font-black tracking-tight text-gray-900 mb-2">
          提示词平台
        </h2>
        <p class="text-gray-500 font-medium">创建新账户，开始您的旅程</p>
      </div>

      <form class="mt-8 space-y-6" @submit.prevent="handleRegister">
        <div class="space-y-4">
          <div class="input-group">
            <label for="username" class="block text-sm font-semibold text-gray-700 mb-1 ml-1">用户名</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </span>
              <input
                id="username"
                name="username"
                type="text"
                required
                v-model="registerForm.username"
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl leading-5 bg-white/50 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition duration-200 sm:text-sm"
                placeholder="请输入用户名 (3-50字符)"
                minlength="3"
                maxlength="50"
              />
            </div>
            <p class="text-xs text-gray-400 mt-1 ml-1">仅支持字母、数字、下划线和连字符</p>
          </div>

          <div class="input-group">
            <label for="password" class="block text-sm font-semibold text-gray-700 mb-1 ml-1">密码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
              <input
                id="password"
                name="password"
                type="password"
                required
                v-model="registerForm.password"
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl leading-5 bg-white/50 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition duration-200 sm:text-sm"
                placeholder="请输入密码 (至少6位)"
                minlength="6"
              />
            </div>
          </div>

          <div class="input-group">
            <label for="confirmPassword" class="block text-sm font-semibold text-gray-700 mb-1 ml-1">确认密码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z" />
                </svg>
              </span>
              <input
                id="confirmPassword"
                name="confirmPassword"
                type="password"
                required
                v-model="registerForm.confirmPassword"
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl leading-5 bg-white/50 placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition duration-200 sm:text-sm"
                placeholder="请再次输入密码"
                minlength="6"
              />
            </div>
          </div>
        </div>

        <div>
          <button
            type="submit"
            :disabled="loading"
            class="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-bold rounded-xl text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-200 transform hover:-translate-y-0.5 active:translate-y-0 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-blue-500/25"
          >
            <span v-if="loading" class="flex items-center">
              <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
              </svg>
              注册中...
            </span>
            <span v-else>立即注册</span>
          </button>
        </div>
        
        <div v-if="errorMsg" class="error-msg p-3 rounded-lg bg-red-50 text-red-500 text-sm text-center border border-red-100 animate-shake">
          {{ errorMsg }}
        </div>

        <div v-if="successMsg" class="success-msg p-3 rounded-lg bg-green-50 text-green-600 text-sm text-center border border-green-100">
          {{ successMsg }}
        </div>
      </form>

      <div class="text-center text-sm text-gray-500 pt-4">
        已有账号？ <router-link to="/login" class="font-bold text-blue-600 hover:text-blue-500">立即登录</router-link>
      </div>
    </div>
  </div>
</template>

<style scoped>
.register-container {
  background-color: #f0f4f9;
  background-image: 
    radial-gradient(at 0% 0%, rgba(26, 115, 232, 0.05) 0, transparent 50%),
    radial-gradient(at 50% 0%, rgba(26, 115, 232, 0.05) 0, transparent 50%),
    radial-gradient(at 100% 0%, rgba(26, 115, 232, 0.05) 0, transparent 50%);
  position: relative;
  overflow: hidden;
}

.bg-decoration {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 0;
  pointer-events: none;
}

.circle {
  position: absolute;
  border-radius: 50%;
  filter: blur(80px);
  opacity: 0.4;
  animation: float 20s infinite alternate;
}

.circle-1 {
  width: 400px;
  height: 400px;
  background: #1a73e8;
  top: -100px;
  right: -100px;
}

.circle-2 {
  width: 300px;
  height: 300px;
  background: #8ab4f8;
  bottom: -50px;
  left: -50px;
  animation-delay: -5s;
}

.circle-3 {
  width: 250px;
  height: 250px;
  background: #e8f0fe;
  top: 40%;
  left: 20%;
  animation-delay: -10s;
}

@keyframes float {
  0% { transform: translate(0, 0) scale(1); }
  33% { transform: translate(30px, -50px) scale(1.1); }
  66% { transform: translate(-20px, 20px) scale(0.9); }
  100% { transform: translate(0, 0) scale(1); }
}

.register-card {
  background: rgba(255, 255, 255, 0.8);
  position: relative;
  z-index: 1;
}

.animate-shake {
  animation: shake 0.5s cubic-bezier(.36,.07,.19,.97) both;
}

@keyframes shake {
  10%, 90% { transform: translate3d(-1px, 0, 0); }
  20%, 80% { transform: translate3d(2px, 0, 0); }
  30%, 50%, 70% { transform: translate3d(-4px, 0, 0); }
  40%, 60% { transform: translate3d(4px, 0, 0); }
}

.logo-icon {
  display: inline-flex;
  padding: 12px;
  background: white;
  border-radius: 20px;
  box-shadow: 0 10px 25px -5px rgba(26, 115, 232, 0.1);
}
</style>

<script setup lang="ts">
import { ref, reactive } from 'vue'
import { useRouter } from 'vue-router'
import { register } from '@/api/auth'

const router = useRouter()

const registerForm = reactive({
  username: '',
  password: '',
  confirmPassword: ''
})

const loading = ref(false)
const errorMsg = ref('')
const successMsg = ref('')

const handleRegister = async () => {
  errorMsg.value = ''
  successMsg.value = ''

  if (registerForm.password !== registerForm.confirmPassword) {
    errorMsg.value = '两次输入的密码不一致'
    return
  }

  const usernamePattern = /^[a-zA-Z0-9_-]+$/
  if (!usernamePattern.test(registerForm.username)) {
    errorMsg.value = '用户名只能包含字母、数字、下划线和连字符'
    return
  }

  loading.value = true
  try {
    const data = await register({
      username: registerForm.username,
      password: registerForm.password
    })
    
    if (data.success) {
      successMsg.value = '注册成功！即将跳转到登录页面...'
      setTimeout(() => {
        router.push('/login')
      }, 1500)
    } else {
      errorMsg.value = data.message || '注册失败，请稍后重试'
    }
  } catch (error: any) {
    // 根据错误类型显示友好的提示信息
    const status = error.response?.status
    if (status === 400) {
      errorMsg.value = '用户名已存在或输入信息有误'
    } else if (status === 401) {
      errorMsg.value = '登录已过期，请重新登录'
    } else if (status === 500) {
      errorMsg.value = '服务器繁忙，请稍后再试'
    } else if (!navigator.onLine) {
      errorMsg.value = '网络连接失败，请检查网络设置'
    } else {
      errorMsg.value = '注册失败，请稍后重试'
    }
  } finally {
    loading.value = false
  }
}
</script>

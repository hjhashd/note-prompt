<template>
  <div class="change-password-container min-h-screen flex items-center justify-center p-4">
    <div class="bg-decoration">
      <div class="circle circle-1"></div>
      <div class="circle circle-2"></div>
      <div class="circle circle-3"></div>
    </div>

    <div class="change-password-card max-w-md w-full space-y-8 p-10 rounded-3xl shadow-2xl backdrop-blur-xl border border-white/20">
      <div class="text-center">
        <h2 class="text-3xl font-bold text-gray-900 mb-2">修改密码</h2>
        <p class="text-gray-500">请输入账号和原密码验证身份</p>
      </div>

      <form class="mt-8 space-y-6" @submit.prevent="handleChangePassword">
        <div class="space-y-4">
          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1 ml-1">账号 / 电话号码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                </svg>
              </span>
              <input
                v-model="form.username"
                type="text"
                required
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl bg-white/50 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入账号"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1 ml-1">原密码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
                </svg>
              </span>
              <input
                v-model="form.oldPassword"
                type="password"
                required
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl bg-white/50 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请输入原密码"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1 ml-1">新密码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z" />
                </svg>
              </span>
              <input
                v-model="form.newPassword"
                type="password"
                required
                minlength="6"
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl bg-white/50 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="至少6位，包含字母和数字"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm font-semibold text-gray-700 mb-1 ml-1">确认新密码</label>
            <div class="relative">
              <span class="absolute inset-y-0 left-0 pl-3 flex items-center text-gray-400">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </span>
              <input
                v-model="form.confirmPassword"
                type="password"
                required
                class="block w-full pl-10 pr-3 py-3 border border-gray-200 rounded-xl bg-white/50 focus:outline-none focus:ring-2 focus:ring-blue-500"
                placeholder="请再次输入新密码"
              />
            </div>
          </div>
        </div>

        <button
          type="submit"
          :disabled="loading"
          class="group relative w-full flex justify-center py-3 px-4 border border-transparent text-sm font-bold rounded-xl text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-blue-500/25"
        >
          <span v-if="loading" class="flex items-center">
            <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            重置中...
          </span>
          <span v-else>确认重置</span>
        </button>

        <div class="text-center text-sm">
          <router-link to="/login" class="font-medium text-blue-600 hover:text-blue-500 transition-colors">
            返回登录
          </router-link>
        </div>

        <div v-if="errorMsg" class="error-msg p-3 rounded-lg bg-red-50 text-red-500 text-sm text-center border border-red-100 animate-shake">
          {{ errorMsg }}
        </div>

        <div v-if="successMsg" class="p-3 rounded-lg bg-green-50 text-green-500 text-sm text-center border border-green-100">
          {{ successMsg }}
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import { reactive, ref } from 'vue'
import { useRouter } from 'vue-router'
import { changePassword } from '@/api/auth'

const router = useRouter()

const form = reactive({
  username: '',
  oldPassword: '',
  newPassword: '',
  confirmPassword: ''
})

const loading = ref(false)
const errorMsg = ref('')
const successMsg = ref('')

const handleChangePassword = async () => {
  if (form.newPassword !== form.confirmPassword) {
    errorMsg.value = '两次输入的新密码不一致'
    return
  }

  if (form.newPassword.length < 6) {
    errorMsg.value = '新密码长度至少6位'
    return
  }

  loading.value = true
  errorMsg.value = ''
  successMsg.value = ''

  try {
    await changePassword(form)
    successMsg.value = '密码修改成功，正在跳转到登录页...'
    
    setTimeout(() => {
      router.push('/login')
    }, 1500)
  } catch (error: any) {
    // 根据错误类型显示友好的提示信息
    const status = error.response?.status
    if (status === 400) {
      errorMsg.value = '原密码错误，请重新输入'
    } else if (status === 401) {
      errorMsg.value = '登录已过期，请重新登录'
    } else if (status === 500) {
      errorMsg.value = '服务器繁忙，请稍后再试'
    } else if (!navigator.onLine) {
      errorMsg.value = '网络连接失败，请检查网络设置'
    } else {
      errorMsg.value = '密码修改失败，请检查账号和原密码'
    }
  } finally {
    loading.value = false
  }
}
</script>

<style scoped>
.change-password-container {
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

.change-password-card {
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
</style>

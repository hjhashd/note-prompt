<script setup lang="ts">
import { onMounted } from 'vue'
import { RouterView } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { usePerformance } from '@/composables/usePerformance'
import ToastContainer from '@/components/ui/Toast/ToastContainer.vue'

const userStore = useUserStore()
const { initPerformanceMonitoring } = usePerformance()

// 3.1 身份认证
onMounted(() => {
  initPerformanceMonitoring()

  const urlParams = new URLSearchParams(window.location.search)
  const token = urlParams.get('token')

  if (token) {
    userStore.setToken(token)
    // 清除 URL 中的 token 参数，保持 URL 干净
    const newUrl = window.location.protocol + "//" + window.location.host + window.location.pathname + window.location.hash;
    window.history.replaceState({path: newUrl}, '', newUrl);
  }
  // 移除 else 分支的警告，因为路由守卫会处理未登录的情况（跳转到登录页）
})
</script>

<template>
  <RouterView />
  <ToastContainer />
</template>

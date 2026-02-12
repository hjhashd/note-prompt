<script setup lang="ts">
import { onMounted, computed } from 'vue'
import { RouterView, useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { useAppStore } from '@/stores/app'
import { usePerformance } from '@/composables/usePerformance'
import ToastContainer from '@/components/ui/Toast/ToastContainer.vue'
import Sidebar from '@/components/layout/Sidebar.vue'

const userStore = useUserStore()
const appStore = useAppStore()
const route = useRoute()
const { initPerformanceMonitoring } = usePerformance()

const showSidebar = computed(() => {
  return route.meta.hideSidebar !== true
})

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
  <div class="app-layout">
    <!-- Global Sidebar managed in App.vue for persistence -->
    <Sidebar 
      v-if="showSidebar"
      :collapsed="appStore.isSidebarCollapsed" 
      @toggle="appStore.toggleSidebar" 
    />
    
    <main 
      class="main-content" 
      :class="{ 
        collapsed: appStore.isSidebarCollapsed,
        'full-width': !showSidebar
      }"
    >
      <router-view v-slot="{ Component }">
        <keep-alive include="PublicFolder,MyPromptsView">
          <component :is="Component" />
        </keep-alive>
      </router-view>
    </main>
  </div>
  <ToastContainer />
</template>

<style scoped>
.app-layout {
  display: flex;
  min-height: 100vh;
  background-color: var(--bg-primary);
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  min-width: 0;
  background: transparent;
  height: 100vh;
  transition: margin-left var(--transition-normal);
  overflow: hidden;
}

.main-content.collapsed {
  margin-left: var(--sidebar-width-collapsed);
}

.main-content.full-width {
  margin-left: 0;
}
</style>

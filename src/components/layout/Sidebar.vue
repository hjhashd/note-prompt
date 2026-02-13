<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { 
  PanelLeft,
  Home, 
  FolderOpen, 
  User, 
  Shield,
  LogOut
} from 'lucide-vue-next'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const props = defineProps<{
  collapsed: boolean
}>()

const emit = defineEmits<{
  (e: 'toggle'): void
}>()

const isMenuOpen = ref(false)
const userProfileRef = ref<HTMLElement | null>(null)

const toggleMenu = (event: Event) => {
  event.stopPropagation()
  isMenuOpen.value = !isMenuOpen.value
}

const handleClickOutside = (event: MouseEvent) => {
  if (isMenuOpen.value && userProfileRef.value && !userProfileRef.value.contains(event.target as Node)) {
    isMenuOpen.value = false
  }
}

onMounted(() => {
  document.addEventListener('click', handleClickOutside)
})

onUnmounted(() => {
  document.removeEventListener('click', handleClickOutside)
})

const handleLogout = () => {
  userStore.clearToken()
  router.push('/login')
}

const activeNav = ref('home')

const routeMap: Record<string, string> = {
  home: '/',
  'my-prompts': '/my-prompts',
  profile: '/profile',
  admin: '/admin',
  studio: '/studio' // Map studio route
}

const syncActiveFromRoute = () => {
  const currentPath = route.path
  // Special handling for studio to highlight 'my-prompts'
  if (currentPath === '/studio') {
    activeNav.value = 'my-prompts'
    return
  }
  
  const matched = Object.entries(routeMap).find(([, path]) => path === currentPath)
  activeNav.value = matched ? matched[0] : 'home'
}

const navigateTo = (page: string) => {
  const targetPath = routeMap[page]
  if (targetPath && targetPath !== route.path) {
    router.push(targetPath)
  }
}

watch(
  () => route.path,
  () => {
    syncActiveFromRoute()
  },
  { immediate: true }
)

const navItems = [
  { id: 'home', label: '提示词广场', icon: FolderOpen },
  { id: 'my-prompts', label: '我的提示词', icon: Home },
  { id: 'profile', label: '个人中心', icon: User },
  { id: 'admin', label: '管理员面板', icon: Shield }
]
</script>

<template>
  <aside class="sidebar" :class="{ collapsed: props.collapsed }" id="sidebar">
    <!-- Header / Logo -->
    <div class="sidebar-header">
      <transition name="fade">
        <div class="logo-container" v-if="!props.collapsed">
          <div class="logo-icon">
            <svg viewBox="0 0 80 80" fill="none" xmlns="http://www.w3.org/2000/svg">
              <circle cx="40" cy="40" r="37" fill="#3B82F6"/>
              <path d="M25 25L41 40L25 55" stroke="#FFFFFF" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>
              <path d="M47 48H58" stroke="#FFFFFF" stroke-width="4" stroke-linecap="round"/>
              <circle cx="51" cy="32" r="2.5" fill="#FFFFFF"/>
            </svg>
          </div>
          <span class="logo-text">提示词平台</span>
        </div>
      </transition>
      
      <button 
        class="sidebar-toggle" 
        @click="emit('toggle')" 
        :class="{ collapsed: props.collapsed }"
        :title="props.collapsed ? '展开侧边栏' : '收起侧边栏'"
      >
        <PanelLeft :size="20" class="toggle-icon" />
      </button>
    </div>

    <!-- Navigation -->
    <nav class="sidebar-nav">
      <ul>
        <li v-for="item in navItems" :key="item.id">
          <a href="#" 
             class="nav-item" 
             :class="{ active: activeNav === item.id }"
             @click.prevent="navigateTo(item.id)"
             :title="props.collapsed ? item.label : ''">
            <span class="nav-icon">
              <component :is="item.icon" :size="20" />
            </span>
            <transition name="fade">
              <span class="nav-text" v-if="!props.collapsed">{{ item.label }}</span>
            </transition>
          </a>
        </li>
      </ul>
    </nav>

    <!-- Footer Area (User Profile with Menu) -->
    <div class="sidebar-footer">
      <!-- User Menu Dropdown -->
      <transition name="slide-up">
        <div class="user-menu" v-if="isMenuOpen">
          <button class="menu-item logout" @click="handleLogout">
            <LogOut :size="18" />
            <span>退出登录</span>
          </button>
        </div>
      </transition>

      <div class="user-profile" @click="toggleMenu" :class="{ active: isMenuOpen }" ref="userProfileRef">
        <div class="avatar">
          <span>{{ userStore.userInfo?.username?.charAt(0)?.toUpperCase() || 'U' }}</span>
        </div>
        <transition name="fade">
          <div class="user-info" v-if="!props.collapsed">
            <div class="user-name">{{ userStore.userInfo?.username || 'User' }}</div>
          </div>
        </transition>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  width: var(--sidebar-width);
  height: 100vh;
  position: fixed;
  left: 0;
  top: 0;
  display: flex;
  flex-direction: column;
  transition: width 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 50;
  background: var(--bg-primary);
  border-right: 1px solid rgba(0, 0, 0, 0.04);
  padding: 16px;
}

.sidebar.collapsed {
  width: var(--sidebar-width-collapsed);
}

/* Border highlight effect (Permanently visible) */
.sidebar::before {
  content: '';
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 2px;
  background: var(--primary-500);
  opacity: 0.12;
  transition: opacity 0.3s ease;
  z-index: 101;
  pointer-events: none;
}

.sidebar:hover::before {
  opacity: 0.25;
}

/* Header */
.sidebar-header {
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 4px;
  margin-bottom: 24px;
  overflow: hidden;
  transition: all 0.3s ease;
}

.sidebar.collapsed .sidebar-header {
  justify-content: center;
  padding: 0;
  margin-bottom: 24px;
}

.logo-container {
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
  white-space: nowrap;
  flex: 1;
}

.logo-icon {
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.logo-icon svg {
  width: 28px;
  height: 28px;
}

.logo-text {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: -0.01em;
}

/* Sidebar Toggle */
.sidebar-toggle {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  border-radius: 8px;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.2s ease;
  flex-shrink: 0;
}

.sidebar-toggle:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.toggle-icon {
  transition: transform 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.sidebar.collapsed .sidebar-toggle {
  width: 40px;
  height: 40px;
}

/* Navigation */
.sidebar-nav {
  flex: 1;
  overflow-y: auto;
  overflow-x: hidden;
}

.sidebar-nav ul {
  list-style: none;
  padding: 0;
  margin: 0;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.nav-item {
  display: flex;
  align-items: center;
  height: 48px;
  padding: 0 16px;
  border-radius: 24px;
  color: var(--text-secondary);
  text-decoration: none;
  transition: all 0.2s ease;
  font-weight: 500;
  font-size: 14px;
  white-space: nowrap;
  overflow: hidden;
}

.sidebar.collapsed .nav-item {
  padding: 0;
  justify-content: center;
  width: 48px;
  margin: 0 auto;
}

.nav-item:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.nav-item.active {
  background: #e8f0fe;
  color: #1a73e8;
}

.nav-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 24px;
}

.nav-text {
  margin-left: 12px;
}

/* Footer Area */
.sidebar-footer {
  margin-top: auto;
  display: flex;
  flex-direction: column;
  gap: 12px;
}

/* User Profile */
.user-profile {
  display: flex;
  align-items: center;
  padding: 10px;
  border-radius: 24px;
  cursor: pointer;
  transition: all 0.2s ease;
  overflow: hidden;
  white-space: nowrap;
  border: 1px solid transparent;
}

.user-profile:hover {
  background: var(--bg-secondary);
}

.user-profile.active {
  background: var(--bg-secondary);
}

.sidebar.collapsed .user-profile {
  justify-content: center;
  padding: 0;
  width: 48px;
  height: 48px;
  margin: 0 auto;
}

.avatar {
  width: 32px;
  height: 32px;
  background: var(--primary);
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
  border: 1px solid rgba(0, 0, 0, 0.05);
}

.user-info {
  margin-left: 12px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.user-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
}

.user-menu {
  position: absolute;
  bottom: 80px;
  left: 16px;
  right: 16px;
  background: var(--bg-surface);
  border-radius: var(--radius-xl);
  box-shadow: 0 10px 30px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(0, 0, 0, 0.05);
  padding: 8px;
  z-index: 100;
}

.sidebar.collapsed .user-menu {
  width: 180px;
  left: 72px;
  bottom: 16px;
}

.menu-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-radius: 12px;
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 14px;
  color: var(--text-secondary);
  transition: all 0.2s ease;
}

.menu-item:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.menu-item.logout {
  color: #d93025;
}

.menu-item.logout:hover {
  background: #fff0f0;
}

/* Responsive Adjustments */
@media (max-width: 768px) {
  /* You can add mobile-specific styles for .sidebar-toggle here if needed */
}

/* Transitions */
.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}

.slide-up-enter-active,
.slide-up-leave-active {
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
}

.slide-up-enter-from,
.slide-up-leave-to {
  opacity: 0;
  transform: translateY(10px);
}

.sidebar.collapsed .slide-up-enter-from,
.sidebar.collapsed .slide-up-leave-to {
  transform: translateX(-10px);
}
</style>

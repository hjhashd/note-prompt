<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { 
  PanelLeftClose, 
  PanelLeftOpen, 
  Home, 
  FolderOpen, 
  Heart, 
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
  public: '/public',
  favorites: '/favorites',
  profile: '/profile',
  admin: '/admin',
}

const syncActiveFromRoute = () => {
  const currentPath = route.path
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
  { id: 'home', label: '我的提示词', icon: Home },
  { id: 'public', label: '公共文件夹', icon: FolderOpen },
  { id: 'favorites', label: '我的收藏', icon: Heart },
  { id: 'profile', label: '个人中心', icon: User },
  { id: 'admin', label: '管理员面板', icon: Shield }
]
</script>

<template>
  <aside class="sidebar" :class="{ collapsed: props.collapsed }" id="sidebar">
    <!-- Header / Logo + Toggle -->
    <div class="sidebar-header">
      <div class="logo-container">
        <div class="logo-icon">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"/>
          </svg>
        </div>
        <transition name="fade">
          <span class="logo-text" v-if="!props.collapsed">NotePrompt</span>
        </transition>
      </div>
      
      <!-- Toggle Button (Restored to Header) -->
      <button class="sidebar-toggle" @click="emit('toggle')" :title="props.collapsed ? '展开侧边栏' : '收起侧边栏'">
        <component :is="props.collapsed ? PanelLeftOpen : PanelLeftClose" :size="20" />
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
  transition: width var(--transition-normal) cubic-bezier(0.4, 0, 0.2, 1);
  z-index: 50;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--border-subtle);
  padding: 12px;
}

.sidebar.collapsed {
  width: var(--sidebar-width-collapsed);
}

/* Header */
.sidebar-header {
  height: 64px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0 12px;
  margin-bottom: 24px;
  overflow: hidden; /* Prevent content jumping */
}

.sidebar.collapsed .sidebar-header {
  justify-content: center;
  flex-direction: column;
  gap: 12px;
  padding: 0;
}

.logo-container {
  display: flex;
  align-items: center;
  gap: 12px;
  overflow: hidden;
  white-space: nowrap;
}

.logo-icon {
  width: 32px;
  height: 32px;
  background: var(--bg-surface);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--primary);
  box-shadow: var(--shadow-sm);
  flex-shrink: 0;
}

.logo-icon svg {
  width: 20px;
  height: 20px;
}

.logo-text {
  font-size: 20px;
  font-weight: 500;
  color: var(--text-primary);
  letter-spacing: -0.5px;
}

.sidebar-toggle {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
  flex-shrink: 0;
}

.sidebar-toggle:hover {
  background: rgba(0,0,0,0.05);
  color: var(--text-primary);
}

.sidebar.collapsed .sidebar-toggle {
  margin-top: 4px; /* Slight adjustment when stacked vertically */
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
  gap: 4px;
}

.nav-item {
  display: flex;
  align-items: center;
  height: 48px;
  padding: 0 16px;
  border-radius: 24px;
  color: var(--text-secondary);
  text-decoration: none;
  transition: all var(--transition-fast);
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
  background: rgba(0,0,0,0.05);
  color: var(--text-primary);
}

.nav-item.active {
  background: var(--primary-light);
  color: var(--primary);
}

.nav-icon {
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  width: 20px; /* Ensure fixed width for icon container */
}

.nav-text {
  margin-left: 12px;
}

/* Footer Area */
.sidebar-footer {
  margin-top: auto;
  display: flex;
  flex-direction: column;
  gap: 8px;
}

/* User Profile */
.user-profile {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  border-radius: 12px;
  cursor: pointer;
  transition: all var(--transition-fast);
  overflow: hidden;
  white-space: nowrap;
  border: 1px solid transparent;
}

.user-profile:hover {
  background: var(--bg-surface);
  border-color: var(--border-subtle);
  box-shadow: var(--shadow-sm);
}

.user-profile.active {
  background: var(--bg-surface);
  border-color: var(--border-subtle);
}

.sidebar.collapsed .user-profile {
  justify-content: center;
  padding: 0;
  width: 40px;
  height: 40px;
  margin: 0 auto;
  border-radius: 50%;
}

.avatar {
  width: 32px;
  height: 32px;
  background: linear-gradient(135deg, var(--primary), var(--primary-600));
  color: white;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-weight: 600;
  font-size: 14px;
  flex-shrink: 0;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  border: 2px solid white;
}

.user-info {
  margin-left: 10px;
  display: flex;
  flex-direction: column;
  justify-content: center;
}

.user-name {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: 0.01em;
}

.user-menu {
  position: absolute;
  bottom: 70px;
  left: 12px;
  right: 12px;
  background: white;
  border-radius: var(--radius-md);
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
  border: 1px solid var(--border-light);
  padding: 4px;
  z-index: 100;
}

.sidebar.collapsed .user-menu {
  width: 160px;
  left: 60px;
  bottom: 12px;
}

.menu-item {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: var(--radius-sm);
  border: none;
  background: transparent;
  cursor: pointer;
  font-size: 14px;
  color: var(--text-secondary);
  transition: all var(--transition-fast);
}

.menu-item:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.menu-item.logout {
  color: #ef4444;
}

.menu-item.logout:hover {
  background: #fef2f2;
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

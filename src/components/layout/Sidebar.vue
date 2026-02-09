<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { 
  ChevronLeft,
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
  'my-prompts': '/my-prompts',
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
  { id: 'home', label: '公共文件夹', icon: FolderOpen },
  { id: 'my-prompts', label: '我的提示词', icon: Home },
  { id: 'favorites', label: '我的收藏', icon: Heart },
  { id: 'profile', label: '个人中心', icon: User },
  { id: 'admin', label: '管理员面板', icon: Shield }
]
</script>

<template>
  <aside class="sidebar" :class="{ collapsed: props.collapsed }" id="sidebar">
    <!-- Header / Logo -->
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
    </div>

    <!-- Toggle Button (Floating on Border) -->
    <button 
      class="sidebar-toggle-floating" 
      @click="emit('toggle')" 
      :class="{ collapsed: props.collapsed }"
      :title="props.collapsed ? '展开侧边栏' : '收起侧边栏'"
    >
      <ChevronLeft :size="16" class="toggle-icon" />
    </button>

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
  background: var(--bg-surface);
  border-right: 1px solid rgba(0, 0, 0, 0.05);
  padding: 16px;
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
  padding: 0 8px;
  margin-bottom: 32px;
  overflow: hidden;
}

.sidebar.collapsed .sidebar-header {
  justify-content: center;
  flex-direction: column;
  gap: 16px;
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
  background: var(--text-primary);
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--bg-surface);
  flex-shrink: 0;
}

.logo-icon svg {
  width: 20px;
  height: 20px;
}

.logo-text {
  font-size: 20px;
  font-weight: 600;
  color: var(--text-primary);
  letter-spacing: -0.02em;
}

/* Floating Toggle Button */
.sidebar-toggle-floating {
  position: absolute;
  right: -12px;
  top: 48px;
  width: 24px;
  height: 24px;
  background: var(--bg-surface);
  border: 1px solid var(--border-light);
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  z-index: 100;
  color: var(--text-secondary);
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.05), 0 1px 2px rgba(0, 0, 0, 0.1);
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  opacity: 0;
  backdrop-filter: blur(8px);
}

/* Hitbox to make it easier to hover */
.sidebar::after {
  content: '';
  position: absolute;
  right: -10px;
  top: 0;
  bottom: 0;
  width: 20px;
  z-index: 99;
}

.sidebar:hover .sidebar-toggle-floating,
.sidebar-toggle-floating:hover {
  opacity: 1;
}

.sidebar-toggle-floating:hover {
  background: var(--primary);
  color: white;
  border-color: var(--primary);
  box-shadow: 0 0 0 4px var(--primary-light), 0 4px 12px rgba(26, 115, 232, 0.2);
  transform: scale(1.15);
}

.toggle-icon {
  transition: transform 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

.sidebar-toggle-floating.collapsed .toggle-icon {
  transform: rotate(180deg);
}

.sidebar-toggle-floating.collapsed {
  opacity: 1;
}

/* Border highlight effect on hover */
.sidebar::before {
  content: '';
  position: absolute;
  right: 0;
  top: 0;
  bottom: 0;
  width: 2px;
  background: var(--primary);
  opacity: 0;
  transition: opacity 0.3s ease;
  z-index: 101;
  pointer-events: none;
}

.sidebar:hover::before {
  opacity: 0.1;
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
  background: var(--bg-primary);
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
  background: var(--bg-primary);
}

.user-profile.active {
  background: var(--bg-primary);
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
  background: var(--bg-secondary);
  color: var(--text-primary);
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
  .sidebar-toggle-floating {
    width: 32px;
    height: 32px;
    right: -16px;
    opacity: 1; /* Always show on mobile for better accessibility */
    background: var(--primary);
    color: white;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }
  
  .sidebar-toggle-floating.collapsed {
    right: -16px;
  }
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

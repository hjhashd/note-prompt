import { createRouter, createWebHistory } from 'vue-router'
import PublicFolder from '@/views/PublicFolder.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  scrollBehavior(to, from, savedPosition) {
    if (savedPosition) {
      return savedPosition
    } else {
      return { top: 0 }
    }
  },
  routes: [
    {
      path: '/',
      name: 'home',
      component: PublicFolder,
      meta: { requiresAuth: true }
    },
    {
      path: '/my-prompts',
      name: 'my-prompts',
      component: () => import('../views/MyPromptsView.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/profile',
      name: 'profile',
      component: () => import('../views/ProfileCenter.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/admin',
      name: 'admin',
      component: () => import('../views/AdminPanel.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/studio',
      name: 'studio',
      component: () => import('../views/PromptStudio.vue'),
      meta: { requiresAuth: true }
    },
    {
      path: '/login',
      name: 'login',
      component: () => import('../views/LoginView.vue'),
      meta: { guest: true, hideSidebar: true }
    },
    {
      path: '/register',
      name: 'register',
      component: () => import('../views/RegisterView.vue'),
      meta: { guest: true, hideSidebar: true }
    },
  ],
})

// 增强的路由守卫
router.beforeEach((to, _from, next) => {
  const token = localStorage.getItem('auth_token')
  
  // 如果页面需要认证且没有 token
  if (to.meta.requiresAuth && !token) {
    next({ name: 'login', query: { redirect: to.fullPath } })
  } 
  // 如果是登录页且已有 token，直接去首页
  else if (to.name === 'login' && token) {
    next({ name: 'home' })
  }
  else {
    next()
  }
})

export default router

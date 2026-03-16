<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { 
  Users, 
  FileText, 
  Heart, 
  Activity, 
  TrendingUp,
  Eye,
  Edit,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Search,
  Plus,
  Trash2,
  KeyRound,
  Power
} from 'lucide-vue-next'
import {
  getSystemStats,
  getTopUsers,
  getTopPrompts,
  getUsersList,
  getUserDetail,
  deleteUser,
  updateUserStatus,
  type SystemStats,
  type TopUser,
  type TopPrompt,
  type UserListItem
} from '@/api/admin'
import { useToast } from '@/composables/useToast'
import UserFormModal from '@/components/admin/UserFormModal.vue'
import ResetPasswordModal from '@/components/admin/ResetPasswordModal.vue'

const { toast } = useToast()

const loading = ref({
  stats: false,
  topUsers: false,
  topPrompts: false,
  users: false
})

const systemStats = ref<SystemStats>({
  total_users: 0,
  total_prompts: 0,
  total_likes: 0,
  total_uses: 0,
  total_favorites: 0,
  total_shares: 0,
  total_views: 0,
  active_users_today: 0,
  new_prompts_today: 0
})

const stats = computed(() => [
  { 
    id: 1, 
    title: '总用户数', 
    value: systemStats.value.total_users.toLocaleString(), 
    change: `今日活跃 ${systemStats.value.active_users_today}`, 
    isPositive: true, 
    icon: Users, 
    type: 'total' 
  },
  { 
    id: 2, 
    title: '提示词总数', 
    value: systemStats.value.total_prompts.toLocaleString(), 
    change: `今日新增 ${systemStats.value.new_prompts_today}`, 
    isPositive: true, 
    icon: FileText, 
    type: 'collections' 
  },
  { 
    id: 3, 
    title: '总点赞数', 
    value: systemStats.value.total_likes >= 1000 
      ? (systemStats.value.total_likes / 1000).toFixed(1) + 'k' 
      : systemStats.value.total_likes.toString(), 
    change: `收藏 ${systemStats.value.total_favorites}`, 
    isPositive: true, 
    icon: Heart, 
    type: 'likes' 
  },
  { 
    id: 4, 
    title: '总使用次数', 
    value: systemStats.value.total_uses >= 1000 
      ? (systemStats.value.total_uses / 1000).toFixed(1) + 'k' 
      : systemStats.value.total_uses.toString(), 
    change: `查看 ${systemStats.value.total_views >= 1000 ? (systemStats.value.total_views / 1000).toFixed(1) + 'k' : systemStats.value.total_views}`, 
    isPositive: true, 
    icon: Activity, 
    type: 'uses' 
  }
])

const selectedUser = ref('all')
const graphType = ref('interaction')

const topUsers = ref<TopUser[]>([])
const popularPrompts = ref<TopPrompt[]>([])

const usersList = ref<UserListItem[]>([])
const usersPagination = ref({
  page: 1,
  page_size: 10,
  total: 0,
  total_pages: 0
})
const searchKeyword = ref('')
const selectedStatus = ref('')

const selectedUserDetail = ref<any>(null)
const showUserModal = ref(false)

const showUserFormModal = ref(false)
const editingUserId = ref<number | null>(null)

const showResetPasswordModal = ref(false)
const resetPasswordUserId = ref<number | null>(null)
const resetPasswordUsername = ref('')

const getRankClass = (rank: number) => {
  if (rank === 1) return 'first'
  if (rank === 2) return 'second'
  if (rank === 3) return 'third'
  return 'other'
}

const formatNumber = (num: number) => {
  if (num >= 1000) {
    return (num / 1000).toFixed(1) + 'k'
  }
  return num.toString()
}

const fetchSystemStats = async () => {
  loading.value.stats = true
  try {
    const data = await getSystemStats()
    systemStats.value = data
  } catch (error) {
    console.error('Failed to fetch system stats:', error)
    toast('获取系统统计失败', 'error')
  } finally {
    loading.value.stats = false
  }
}

const fetchTopUsers = async () => {
  loading.value.topUsers = true
  try {
    const data = await getTopUsers(5)
    topUsers.value = data
  } catch (error) {
    console.error('Failed to fetch top users:', error)
  } finally {
    loading.value.topUsers = false
  }
}

const fetchTopPrompts = async () => {
  loading.value.topPrompts = true
  try {
    const data = await getTopPrompts(5)
    popularPrompts.value = data
  } catch (error) {
    console.error('Failed to fetch top prompts:', error)
  } finally {
    loading.value.topPrompts = false
  }
}

const fetchUsersList = async () => {
  loading.value.users = true
  try {
    const data = await getUsersList({
      page: usersPagination.value.page,
      page_size: usersPagination.value.page_size,
      keyword: searchKeyword.value || undefined,
      status: selectedStatus.value || undefined
    })
    usersList.value = data.list
    usersPagination.value = {
      page: data.page,
      page_size: data.page_size,
      total: data.total,
      total_pages: data.total_pages
    }
  } catch (error) {
    console.error('Failed to fetch users list:', error)
    toast('获取用户列表失败', 'error')
  } finally {
    loading.value.users = false
  }
}

let searchTimeout: ReturnType<typeof setTimeout> | null = null

const handleSearchInput = () => {
  if (searchTimeout) {
    clearTimeout(searchTimeout)
  }
  searchTimeout = setTimeout(() => {
    usersPagination.value.page = 1
    fetchUsersList()
  }, 300)
}

const handleSearch = () => {
  if (searchTimeout) clearTimeout(searchTimeout)
  usersPagination.value.page = 1
  fetchUsersList()
}

const handlePageChange = (page: number) => {
  usersPagination.value.page = page
  fetchUsersList()
}

const viewUserDetail = async (userId: number) => {
  try {
    const data = await getUserDetail(userId)
    selectedUserDetail.value = data
    showUserModal.value = true
  } catch (error) {
    console.error('Failed to fetch user detail:', error)
    toast('获取用户详情失败', 'error')
  }
}

const openCreateUserModal = () => {
  editingUserId.value = null
  showUserFormModal.value = true
}

const openEditUserModal = (userId: number) => {
  editingUserId.value = userId
  showUserFormModal.value = true
}

const openResetPasswordModal = (userId: number, username: string) => {
  resetPasswordUserId.value = userId
  resetPasswordUsername.value = username
  showResetPasswordModal.value = true
}

const handleDeleteUser = async (userId: number, username: string) => {
  if (!confirm(`确定要删除用户 "${username}" 吗？此操作不可恢复。`)) {
    return
  }
  
  try {
    await deleteUser(userId)
    toast('用户删除成功', 'success')
    usersList.value = usersList.value.filter(u => u.id !== userId)
    usersPagination.value.total -= 1
    if (usersList.value.length === 0 && usersPagination.value.page > 1) {
      handlePageChange(usersPagination.value.page - 1)
    }
  } catch (error: any) {
    console.error('Failed to delete user:', error)
    const message = error?.response?.data?.detail || '删除失败'
    toast(message, 'error')
  }
}

const handleToggleStatus = async (userId: number, currentStatus: number) => {
  const newStatus = currentStatus === 1 ? 0 : 1
  const action = newStatus === 1 ? '启用' : '禁用'
  
  const user = usersList.value.find(u => u.id === userId)
  if (user) {
    user._loading = true
  }

  try {
    await updateUserStatus(userId, newStatus)
    toast(`用户${action}成功`, 'success')
    if (user) {
      user.status = newStatus === 1 ? 'Active' : 'Inactive'
    }
  } catch (error: any) {
    console.error('Failed to update user status:', error)
    const message = error?.response?.data?.detail || '操作失败'
    toast(`${message} (点击重试)`, 'error')
  } finally {
    if (user) {
      user._loading = false
    }
  }
}

const handleUserFormSuccess = (payload?: any) => {
  if (payload && payload.type === 'edit') {
    const user = usersList.value.find(u => u.id === payload.id)
    if (user) {
      if (payload.data.realName) user.name = payload.data.realName
      user.status = payload.data.status === 1 ? 'Active' : 'Inactive'
      // 简单起见，如果部门或角色有复杂映射，可以通过重新获取单条数据或直接刷新列表
      // 如果只要求无刷新，这已经处理了大部分
    }
    // 为了保证数据完整性，也可以选择获取单条数据然后合并
    getUserDetail(payload.id).then(data => {
      const u = usersList.value.find(u => u.id === payload.id)
      if (u) {
        u.name = data.name
        u.department_name = data.department_name
        u.status = data.status
        // u.role 等如果有返回也更新
      }
    }).catch(() => {})
  } else {
    fetchUsersList()
  }
}

const handleResetPasswordSuccess = () => {
  toast('密码重置成功', 'success')
}

const refreshAll = async () => {
  await Promise.all([
    fetchSystemStats(),
    fetchTopUsers(),
    fetchTopPrompts(),
    fetchUsersList()
  ])
  toast('数据已刷新', 'success')
}

onMounted(() => {
  refreshAll()
})
</script>

<template>
  <div class="admin-panel">
    <div class="content-body">
      <!-- Page Header -->
      <header class="page-header">
        <div class="header-content">
          <div>
            <h1 class="page-title">管理员面板</h1>
            <p class="page-subtitle">概览系统状态、用户活动及内容表现</p>
          </div>
          <button class="refresh-btn" @click="refreshAll" :disabled="loading.stats">
            <RefreshCw :size="16" :class="{ 'spinning': loading.stats }" />
            刷新数据
          </button>
        </div>
      </header>

      <!-- Stats Grid -->
      <section class="stats-grid">
        <div v-for="stat in stats" :key="stat.id" class="stat-card">
          <div class="stat-header">
            <span class="stat-title">{{ stat.title }}</span>
            <div class="stat-icon" :class="stat.type">
              <component :is="stat.icon" :size="20" />
            </div>
          </div>
          <div class="stat-value">{{ stat.value }}</div>
          <div class="stat-change" :class="{ positive: stat.isPositive, negative: !stat.isPositive }">
            <TrendingUp :size="14" />
            {{ stat.change }}
          </div>
        </div>
      </section>

      <!-- Graph Section -->
      <section class="graph-section">
        <div class="section-header">
          <h2 class="section-title">关系网络分析</h2>
        </div>
        <div class="graph-controls">
          <div class="control-group">
            <label>用户视图:</label>
            <select v-model="selectedUser">
              <option value="all">所有用户</option>
              <option value="active">活跃用户</option>
              <option value="new">新注册用户</option>
            </select>
          </div>
          <div class="control-group">
            <label>图表类型:</label>
            <select v-model="graphType">
              <option value="interaction">交互网络</option>
              <option value="similarity">内容相似度</option>
            </select>
          </div>
        </div>
        
        <div class="graph-container">
          <svg viewBox="0 0 800 400" class="relationship-graph">
            <g class="links">
              <line x1="400" y1="200" x2="250" y2="150" class="link" />
              <line x1="400" y1="200" x2="550" y2="150" class="link" />
              <line x1="400" y1="200" x2="400" y2="300" class="link" />
              <line x1="250" y1="150" x2="150" y2="200" class="link" />
              <line x1="250" y1="150" x2="200" y2="80" class="link" />
              <line x1="550" y1="150" x2="650" y2="200" class="link" />
              <line x1="550" y1="150" x2="600" y2="80" class="link" />
            </g>
            
            <g class="nodes">
              <circle cx="400" cy="200" r="30" class="node node-hub" />
              <text x="400" y="205" text-anchor="middle" class="node-label-text">System</text>
              
              <circle cx="250" cy="150" r="20" class="node node-user" />
              <circle cx="550" cy="150" r="20" class="node node-user" />
              <circle cx="400" cy="300" r="20" class="node node-prompt" />
              
              <circle cx="150" cy="200" r="15" class="node node-prompt" />
              <circle cx="200" cy="80" r="15" class="node node-prompt" />
              <circle cx="650" cy="200" r="15" class="node node-prompt" />
              <circle cx="600" cy="80" r="15" class="node node-prompt" />
            </g>
          </svg>
          <div class="graph-legend">
            <div class="legend-item"><span class="dot user"></span> 用户</div>
            <div class="legend-item"><span class="dot prompt"></span> 提示词</div>
            <div class="legend-item"><span class="dot hub"></span> 核心节点</div>
          </div>
        </div>
      </section>

      <!-- Leaderboards Grid -->
      <section class="leaderboards-grid">
        <!-- Top Users -->
        <div class="leaderboard-card">
          <div class="leaderboard-header">
            <h3 class="leaderboard-title">活跃用户排行榜</h3>
          </div>
          <div class="leaderboard-content">
            <div v-if="loading.topUsers" class="loading-state">
              加载中...
            </div>
            <div v-else-if="topUsers.length === 0" class="empty-state">
              暂无数据
            </div>
            <div v-else class="leaderboard-list">
              <div v-for="user in topUsers" :key="user.id" class="leaderboard-item">
                <div class="leaderboard-rank" :class="getRankClass(user.rank)">{{ user.rank }}</div>
                <div class="leaderboard-info">
                  <div class="info-primary">{{ user.name }}</div>
                  <div class="info-secondary">{{ user.prompt_count }} 个提示词 · {{ user.like_count }} 获赞</div>
                </div>
                <div class="leaderboard-score">{{ user.score }} pts</div>
              </div>
            </div>
          </div>
        </div>

        <!-- Popular Prompts -->
        <div class="leaderboard-card">
          <div class="leaderboard-header">
            <h3 class="leaderboard-title">热门提示词排行</h3>
          </div>
          <div class="leaderboard-content">
            <div v-if="loading.topPrompts" class="loading-state">
              加载中...
            </div>
            <div v-else-if="popularPrompts.length === 0" class="empty-state">
              暂无数据
            </div>
            <div v-else class="leaderboard-list">
              <div v-for="prompt in popularPrompts" :key="prompt.id" class="leaderboard-item">
                <div class="leaderboard-rank" :class="getRankClass(prompt.rank)">{{ prompt.rank }}</div>
                <div class="leaderboard-info">
                  <div class="info-primary">{{ prompt.title }}</div>
                  <div class="info-secondary">By {{ prompt.author }}</div>
                </div>
                <div class="leaderboard-score">{{ formatNumber(prompt.score) }} 热度</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Users Table -->
      <section class="users-section">
        <div class="section-header">
          <h2 class="section-title">用户管理</h2>
          <div class="header-actions">
            <button class="add-user-btn" @click="openCreateUserModal">
              <Plus :size="16" />
              新增用户
            </button>
            <div class="search-box">
              <Search :size="16" />
              <input 
                v-model="searchKeyword" 
                type="text" 
                placeholder="搜索用户..." 
                @input="handleSearchInput"
                @keyup.enter="handleSearch"
              />
              <button class="search-btn" @click="handleSearch">搜索</button>
            </div>
          </div>
        </div>
        <div class="table-card">
          <div v-if="loading.users && usersList.length" class="table-loading-overlay">
            <div class="loading-indicator">
              <RefreshCw :size="16" class="spinning" />
              <span>加载中...</span>
            </div>
          </div>
          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th>用户姓名</th>
                  <th>部门</th>
                  <th>角色</th>
                  <th>提示词数</th>
                  <th>状态</th>
                  <th>加入时间</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                <template v-if="loading.users && usersList.length === 0">
                  <tr v-for="i in 5" :key="i" class="skeleton-row">
                    <td><div class="skeleton-text"></div></td>
                    <td><div class="skeleton-text"></div></td>
                    <td><div class="skeleton-badge"></div></td>
                    <td><div class="skeleton-text mini"></div></td>
                    <td><div class="skeleton-status"></div></td>
                    <td><div class="skeleton-text"></div></td>
                    <td><div class="skeleton-actions"></div></td>
                  </tr>
                </template>
                <tr v-else-if="usersList.length === 0">
                  <td colspan="7" class="empty-cell">暂无用户数据</td>
                </tr>
                <tr v-else v-for="user in usersList" :key="user.id">
                  <td>
                    <div class="user-info">
                      <div class="user-name">{{ user.name }}</div>
                      <div class="user-username" v-if="user.username && user.username !== user.name">@{{ user.username }}</div>
                    </div>
                  </td>
                  <td class="text-secondary">{{ user.department_name || '-' }}</td>
                  <td>
                    <span class="badge" :class="user.role === '高级用户' ? 'premium' : 'standard'">
                      {{ user.role }}
                    </span>
                  </td>
                  <td>{{ user.prompt_count }}</td>
                  <td>
                    <span class="status-dot" :class="user.status.toLowerCase()"></span>
                    {{ user.status }}
                  </td>
                  <td class="text-secondary">{{ user.join_date }}</td>
                  <td>
                    <div class="action-buttons">
                      <button class="action-btn" title="查看详情" @click="viewUserDetail(user.id)">
                        <Eye :size="14" />
                      </button>
                      <button class="action-btn" title="编辑用户" @click="openEditUserModal(user.id)">
                        <Edit :size="14" />
                      </button>
                      <button class="action-btn" title="重置密码" @click="openResetPasswordModal(user.id, user.name)">
                        <KeyRound :size="14" />
                      </button>
                      <button 
                        class="action-btn status-btn" 
                        :class="user.status === 'Active' ? 'danger' : 'success'"
                        :title="user.status === 'Active' ? '禁用用户' : '启用用户'"
                        :aria-label="user.status === 'Active' ? '禁用该用户' : '启用该用户'"
                        :disabled="user._loading"
                        @click="handleToggleStatus(user.id, user.status === 'Active' ? 1 : 0)"
                      >
                        <RefreshCw v-if="user._loading" :size="14" class="spinning" />
                        <Power v-else :size="14" />
                        <span class="status-text">{{ user.status === 'Active' ? '禁用' : '启用' }}</span>
                      </button>
                      <button class="action-btn danger" title="删除用户" @click="handleDeleteUser(user.id, user.name)">
                        <Trash2 :size="14" />
                      </button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          
          <!-- Pagination -->
          <div v-if="usersPagination.total_pages > 1" class="pagination">
            <button 
              class="page-btn" 
              :disabled="usersPagination.page === 1"
              @click="handlePageChange(usersPagination.page - 1)"
            >
              <ChevronLeft :size="16" />
            </button>
            <span class="page-info">
              {{ usersPagination.page }} / {{ usersPagination.total_pages }}
            </span>
            <button 
              class="page-btn" 
              :disabled="usersPagination.page === usersPagination.total_pages"
              @click="handlePageChange(usersPagination.page + 1)"
            >
              <ChevronRight :size="16" />
            </button>
          </div>
        </div>
      </section>

    </div>

    <!-- User Detail Modal -->
    <div v-if="showUserModal" class="modal-overlay" @click.self="showUserModal = false">
      <div class="modal-content">
        <div class="modal-header">
          <h3>用户详情</h3>
          <button class="modal-close" @click="showUserModal = false">&times;</button>
        </div>
        <div v-if="selectedUserDetail" class="modal-body">
          <div class="detail-grid">
            <div class="detail-item">
              <span class="detail-label">用户ID</span>
              <span class="detail-value">{{ selectedUserDetail.id }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">用户名</span>
              <span class="detail-value">{{ selectedUserDetail.name }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">部门</span>
              <span class="detail-value">{{ selectedUserDetail.department_name || '-' }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">提示词数量</span>
              <span class="detail-value">{{ selectedUserDetail.prompt_count }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">首次创建</span>
              <span class="detail-value">{{ selectedUserDetail.first_create_time }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">最后活动</span>
              <span class="detail-value">{{ selectedUserDetail.last_create_time }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">总获赞</span>
              <span class="detail-value">{{ selectedUserDetail.total_likes }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">总查看</span>
              <span class="detail-value">{{ selectedUserDetail.total_views }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">总复制</span>
              <span class="detail-value">{{ selectedUserDetail.total_copies }}</span>
            </div>
            <div class="detail-item">
              <span class="detail-label">总收藏</span>
              <span class="detail-value">{{ selectedUserDetail.total_favorites }}</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- User Form Modal -->
    <UserFormModal
      v-model:visible="showUserFormModal"
      :user-id="editingUserId"
      @success="handleUserFormSuccess"
    />

    <!-- Reset Password Modal -->
    <ResetPasswordModal
      v-model:visible="showResetPasswordModal"
      :user-id="resetPasswordUserId"
      :username="resetPasswordUsername"
      @success="handleResetPasswordSuccess"
    />
  </div>
</template>

<style scoped>
.admin-panel {
  height: 100%;
  overflow-y: auto;
  background-color: var(--bg-primary);
}

.content-body {
  padding: 32px;
  background-color: var(--bg-primary);
  max-width: 1200px;
  margin: 0 auto;
}

/* Page Header */
.page-header {
  margin-bottom: 32px;
}

.header-content {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.page-title {
  font-size: 28px;
  font-weight: 700;
  color: var(--gray-900);
  margin-bottom: 8px;
}

.page-subtitle {
  font-size: 15px;
  color: var(--gray-500);
}

.refresh-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  border-radius: var(--radius-md);
  font-size: 14px;
  color: var(--gray-700);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.refresh-btn:hover:not(:disabled) {
  background: var(--bg-primary);
  border-color: var(--primary-light);
  color: var(--primary);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.spinning {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

/* Stats Grid */
.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 20px;
  margin-bottom: 32px;
}

.stat-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  padding: 24px;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
  transition: all var(--transition-normal);
}

.stat-card:hover {
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
  border-color: var(--primary-light);
}

.stat-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.stat-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-500);
}

.stat-icon {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}

.stat-icon.total { background: linear-gradient(135deg, #3b82f6, #2563eb); }
.stat-icon.collections { background: linear-gradient(135deg, #14b8a6, #0d9488); }
.stat-icon.likes { background: linear-gradient(135deg, #f472b6, #ec4899); }
.stat-icon.uses { background: linear-gradient(135deg, #10b981, #059669); }

.stat-value {
  font-size: 32px;
  font-weight: 700;
  color: var(--gray-900);
  margin-bottom: 8px;
}

.stat-change {
  font-size: 12px;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 4px;
}

.stat-change.positive { color: var(--success); }
.stat-change.negative { color: var(--danger); }

/* Section Headers */
.section-header {
  margin-bottom: 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 16px;
}

.section-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--gray-900);
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 16px;
}

.add-user-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: var(--primary);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.add-user-btn:hover {
  background: var(--primary-600);
}

.search-box {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
}

.search-box input {
  border: none;
  outline: none;
  background: transparent;
  font-size: 14px;
  color: var(--gray-900);
  width: 150px;
}

.search-btn {
  padding: 4px 12px;
  background: var(--primary);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  font-size: 12px;
  cursor: pointer;
}

.search-btn:hover {
  background: var(--primary-600);
}

/* Graph Section */
.graph-section {
  margin-bottom: 32px;
}

.graph-controls {
  display: flex;
  gap: 20px;
  margin-bottom: 20px;
  flex-wrap: wrap;
}

.control-group {
  display: flex;
  align-items: center;
  gap: 8px;
}

.control-group label {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-500);
}

.control-group select {
  padding: 8px 12px;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-sm);
  font-size: 14px;
  color: var(--gray-900);
  background: var(--bg-surface);
  outline: none;
}

.graph-container {
  width: 100%;
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  padding: 24px;
  position: relative;
  overflow: hidden;
}

.relationship-graph {
  width: 100%;
  height: 400px;
  background: var(--bg-surface);
}

.link {
  stroke: var(--gray-300);
  stroke-width: 2;
  stroke-opacity: 0.6;
}

.node {
  cursor: pointer;
  transition: r 0.3s ease;
}

.node:hover {
  r: 25;
}

.node-hub { fill: var(--primary-600); }
.node-user { fill: #3b82f6; }
.node-prompt { fill: #14b8a6; }

.node-label-text {
  font-size: 12px;
  fill: white;
  pointer-events: none;
  font-weight: 600;
}

.graph-legend {
  display: flex;
  gap: 16px;
  justify-content: center;
  margin-top: 16px;
}

.legend-item {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: var(--gray-500);
}

.dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.dot.user { background: #3b82f6; }
.dot.prompt { background: #14b8a6; }
.dot.hub { background: var(--primary-600); }


/* Leaderboards Grid */
.leaderboards-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
  gap: 24px;
  margin-bottom: 32px;
}

.leaderboard-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
  overflow: hidden;
}

.leaderboard-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-subtle);
  background: var(--bg-primary);
}

.leaderboard-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--gray-900);
}

.leaderboard-content {
  padding: 20px;
  min-height: 200px;
}

.loading-state,
.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 150px;
  color: var(--gray-500);
  font-size: 14px;
}

.leaderboard-list {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.leaderboard-item {
  display: flex;
  align-items: center;
  gap: 16px;
  padding: 12px;
  border-radius: var(--radius-md);
  transition: background var(--transition-fast);
}

.leaderboard-item:hover {
  background: var(--bg-primary);
}

.leaderboard-rank {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 12px;
  font-weight: 600;
  color: white;
  flex-shrink: 0;
}

.leaderboard-rank.first { background: #FFD700; }
.leaderboard-rank.second { background: #C0C0C0; }
.leaderboard-rank.third { background: #CD7F32; }
.leaderboard-rank.other { background: var(--gray-400); }

.leaderboard-info {
  flex: 1;
  min-width: 0;
}

.info-primary {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-900);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.info-secondary {
  font-size: 12px;
  color: var(--gray-500);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.leaderboard-score {
  font-size: 14px;
  font-weight: 600;
  color: var(--gray-900);
}

/* Users Table */
.users-section {
  margin-bottom: 32px;
}

.table-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
  overflow: hidden;
  position: relative;
}

.table-container {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th {
  text-align: left;
  padding: 16px 24px;
  font-size: 13px;
  font-weight: 600;
  color: var(--gray-500);
  background: var(--bg-primary);
  border-bottom: 1px solid var(--border-subtle);
  white-space: nowrap;
}

td {
  padding: 16px 24px;
  font-size: 14px;
  color: var(--gray-900);
  border-bottom: 1px solid var(--border-subtle);
}

tr:last-child td {
  border-bottom: none;
}

.empty-cell {
  text-align: center;
  color: var(--gray-500);
  padding: 40px !important;
}

/* Skeleton Loading Styles */
.skeleton-row td {
  padding: 16px 24px;
}

.skeleton-text,
.skeleton-badge,
.skeleton-status,
.skeleton-actions {
  background: linear-gradient(90deg, var(--gray-100) 25%, var(--gray-200) 50%, var(--gray-100) 75%);
  background-size: 200% 100%;
  animation: loading 1.5s infinite;
  border-radius: var(--radius-sm);
}

.skeleton-text {
  height: 16px;
  width: 80%;
}

.skeleton-text.mini {
  width: 40%;
}

.skeleton-badge {
  height: 24px;
  width: 60px;
  border-radius: 12px;
}

.skeleton-status {
  height: 16px;
  width: 50px;
}

.skeleton-actions {
  height: 32px;
  width: 140px;
}

.table-loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.65);
  backdrop-filter: blur(1px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2;
}

.loading-indicator {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  border-radius: 999px;
  background: var(--bg-surface);
  color: var(--gray-700);
  font-size: 13px;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
}

@keyframes loading {
  0% {
    background-position: 200% 0;
  }
  100% {
    background-position: -200% 0;
  }
}

.font-medium { font-weight: 500; }
.text-secondary { color: var(--gray-500); }

.badge {
  padding: 4px 8px;
  border-radius: 12px;
  font-size: 12px;
  font-weight: 500;
}

.badge.premium {
  background: #eef2ff;
  color: var(--primary);
}

.badge.standard {
  background: var(--bg-primary);
  color: var(--gray-600);
}

.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
}

.status-dot.active { background: var(--success); }
.status-dot.inactive { background: var(--gray-400); }

.action-buttons {
  display: flex;
  gap: 8px;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 4px;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-sm);
  border: none;
  background: transparent;
  color: var(--gray-500);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.action-btn:hover:not(:disabled) {
  background: var(--bg-surface);
  color: var(--primary);
}

.action-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-btn.danger {
  color: var(--danger);
}

.action-btn.danger:hover:not(:disabled) {
  background: #fef2f2;
}

.action-btn.success {
  color: var(--success);
}

.action-btn.success:hover:not(:disabled) {
  background: #ecfdf5;
}

.action-btn.status-btn {
  width: auto;
  padding: 0 8px;
}

.status-text {
  font-size: 12px;
  font-weight: 500;
}

/* Pagination */
.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  padding: 16px;
  border-top: 1px solid var(--border-subtle);
}

.page-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  border-radius: var(--radius-sm);
  color: var(--gray-700);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.page-btn:hover:not(:disabled) {
  background: var(--bg-primary);
  border-color: var(--primary-light);
  color: var(--primary);
}

.page-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.page-info {
  font-size: 14px;
  color: var(--gray-600);
}

/* Modal */
.modal-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}

.modal-content {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  width: 90%;
  max-width: 500px;
  max-height: 80vh;
  overflow: hidden;
  box-shadow: var(--shadow-lg);
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 24px;
  border-bottom: 1px solid var(--border-subtle);
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--gray-900);
}

.modal-close {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  font-size: 24px;
  color: var(--gray-500);
  cursor: pointer;
  border-radius: var(--radius-sm);
}

.modal-close:hover {
  background: var(--bg-primary);
  color: var(--gray-700);
}

.modal-body {
  padding: 24px;
  overflow-y: auto;
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 16px;
}

.detail-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.detail-label {
  font-size: 12px;
  color: var(--gray-500);
}

.detail-value {
  font-size: 14px;
  font-weight: 500;
  color: var(--gray-900);
}

/* Responsive */
@media (max-width: 768px) {
  .content-body {
    padding: 20px;
  }
  
  .header-content {
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
  }

  .stats-grid {
    grid-template-columns: 1fr;
  }

  .leaderboards-grid {
    grid-template-columns: 1fr;
  }
  
  .detail-grid {
    grid-template-columns: 1fr;
  }
}

/* 用户信息样式 */
.user-info {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.user-name {
  font-weight: 500;
  color: var(--text-primary);
}

.user-username {
  font-size: 12px;
  color: var(--text-secondary);
  font-family: monospace;
}
</style>

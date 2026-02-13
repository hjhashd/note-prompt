<script setup lang="ts">
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { 
  FileText, 
  Heart, 
  ThumbsUp, 
  Share2, 
  Eye,
  Copy,
  Activity, 
  Plus, 
  Edit, 
  Trash2,
  RefreshCw,
  ChevronLeft,
  ChevronRight,
  Loader2
} from 'lucide-vue-next'
import { 
  getUserStats, 
  getUserActivities, 
  getUserPrompts, 
  deletePrompt,
  type UserStats, 
  type ActivityItem, 
  type UserPromptItem 
} from '@/api/promptSave'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()

const loading = ref({
  stats: false,
  activities: false,
  prompts: false
})

const userStats = ref<UserStats>({
  total_prompts: 0,
  favorite_count: 0,
  like_count: 0,
  share_count: 0,
  view_count: 0,
  copy_count: 0
})

const activities = ref<ActivityItem[]>([])

const promptList = ref<UserPromptItem[]>([])
const pagination = ref({
  page: 1,
  page_size: 10,
  total: 0,
  total_pages: 0
})

const statsDisplay = computed(() => [
  { 
    id: 1, 
    label: '总提示词数', 
    value: userStats.value.total_prompts, 
    icon: FileText, 
    colorClass: 'blue' 
  },
  { 
    id: 2, 
    label: '获赞总数', 
    value: userStats.value.like_count, 
    icon: ThumbsUp, 
    colorClass: 'orange' 
  },
  { 
    id: 3, 
    label: '被收藏数', 
    value: userStats.value.favorite_count, 
    icon: Heart, 
    colorClass: 'teal' 
  },
  { 
    id: 4, 
    label: '被查看数', 
    value: userStats.value.view_count, 
    icon: Eye, 
    colorClass: 'purple' 
  },
  { 
    id: 5, 
    label: '被复制数', 
    value: userStats.value.copy_count, 
    icon: Copy, 
    colorClass: 'indigo' 
  },
  { 
    id: 6, 
    label: '分享次数', 
    value: userStats.value.share_count, 
    icon: Share2, 
    colorClass: 'pink' 
  }
])

const getActivityIcon = (iconName: string) => {
  const iconMap: Record<string, any> = {
    Plus: Plus,
    Edit: Edit,
    Share2: Share2,
    ThumbsUp: ThumbsUp,
    Heart: Heart,
    Copy: Copy,
    Activity: Activity
  }
  return iconMap[iconName] || Activity
}

const fetchStats = async () => {
  loading.value.stats = true
  try {
    userStats.value = await getUserStats()
  } catch (error) {
    console.error('Failed to fetch user stats:', error)
  } finally {
    loading.value.stats = false
  }
}

const fetchActivities = async () => {
  loading.value.activities = true
  try {
    activities.value = await getUserActivities(10)
  } catch (error) {
    console.error('Failed to fetch activities:', error)
  } finally {
    loading.value.activities = false
  }
}

const fetchPrompts = async (page = 1) => {
  loading.value.prompts = true
  try {
    const result = await getUserPrompts(page, pagination.value.page_size)
    promptList.value = result.list
    pagination.value = {
      page: result.page,
      page_size: result.page_size,
      total: result.total,
      total_pages: result.total_pages
    }
  } catch (error) {
    console.error('Failed to fetch prompts:', error)
  } finally {
    loading.value.prompts = false
  }
}

const handleDeletePrompt = async (promptId: number) => {
  if (!confirm('确定要删除这个提示词吗？此操作不可恢复。')) {
    return
  }
  
  try {
    await deletePrompt(promptId, false)
    await fetchPrompts(pagination.value.page)
    await fetchStats()
  } catch (error) {
    console.error('Failed to delete prompt:', error)
    alert('删除失败，请重试')
  }
}

const editPrompt = (id: number) => {
  router.push(`/prompt/edit/${id}`)
}

const goToPage = (page: number) => {
  if (page >= 1 && page <= pagination.value.total_pages) {
    fetchPrompts(page)
  }
}

const refreshAll = async () => {
  await Promise.all([
    fetchStats(),
    fetchActivities(),
    fetchPrompts(pagination.value.page)
  ])
}

onMounted(() => {
  refreshAll()
})
</script>

<template>
  <div class="profile-view">
    <header class="page-header">
      <div class="header-content">
        <div class="title-row">
          <h1 class="page-title">我的个人中心</h1>
          <button class="refresh-btn" @click="refreshAll" :disabled="loading.stats || loading.activities || loading.prompts">
            <RefreshCw :size="16" :class="{ 'animate-spin': loading.stats }" />
            刷新
          </button>
        </div>
        <p class="page-desc">
          欢迎回来，{{ userStore.userInfo?.username || '用户' }}！查看您的使用统计和活动记录
        </p>
      </div>
    </header>

    <section class="stats-overview">
      <div v-for="stat in statsDisplay" :key="stat.id" class="stat-card">
        <div class="stat-card-header">
          <div class="stat-icon" :class="stat.colorClass">
            <component :is="stat.icon" :size="20" />
          </div>
        </div>
        <div class="stat-value">
          <Loader2 v-if="loading.stats" :size="24" class="animate-spin" />
          <span v-else>{{ stat.value }}</span>
        </div>
        <div class="stat-label">{{ stat.label }}</div>
      </div>
    </section>

    <section class="activity-section">
      <div class="section-header">
        <h2 class="section-title">
          <Activity :size="18" class="mr-2 inline-block" />
          最近活动
        </h2>
      </div>
      <div class="activity-list">
        <div v-if="loading.activities" class="loading-state">
          <Loader2 :size="24" class="animate-spin" />
          <span>加载中...</span>
        </div>
        <div v-else-if="activities.length === 0" class="empty-state">
          暂无活动记录
        </div>
        <div v-else v-for="activity in activities" :key="activity.id" class="activity-item">
          <div class="activity-icon" :class="activity.type">
            <component :is="getActivityIcon(activity.icon)" :size="16" />
          </div>
          <div class="activity-content">
            <div class="activity-text">
              {{ activity.text }} <strong>{{ activity.highlight }}</strong>
            </div>
            <div class="activity-time">{{ activity.time }}</div>
          </div>
        </div>
      </div>
    </section>

    <section class="prompt-details">
      <div class="section-header">
        <h2 class="section-title">
          <FileText :size="18" class="mr-2 inline-block" />
          我的提示词
          <span v-if="!loading.prompts" class="count-badge">{{ pagination.total }}</span>
        </h2>
      </div>
      <div class="table-container">
        <div v-if="loading.prompts" class="loading-state">
          <Loader2 :size="24" class="animate-spin" />
          <span>加载中...</span>
        </div>
        <div v-else-if="promptList.length === 0" class="empty-state">
          <FileText :size="48" class="empty-icon" />
          <p>暂无提示词</p>
          <button class="create-btn" @click="router.push('/prompt/create')">
            <Plus :size="16" />
            创建第一个提示词
          </button>
        </div>
        <table v-else>
          <thead>
            <tr>
              <th class="text-left">提示词名称</th>
              <th class="text-center">点赞</th>
              <th class="text-center">收藏</th>
              <th class="text-center">复制</th>
              <th class="text-center">查看</th>
              <th class="text-center">创建时间</th>
              <th class="text-center">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in promptList" :key="item.id">
              <td class="font-medium text-gray-800">
                <div class="prompt-title">
                  {{ item.title }}
                  <span v-if="item.status === 2" class="template-badge">公开</span>
                </div>
              </td>
              <td class="text-center">{{ item.like_count }}</td>
              <td class="text-center">{{ item.favorite_count }}</td>
              <td class="text-center">{{ item.copy_count }}</td>
              <td class="text-center">{{ item.view_count }}</td>
              <td class="text-center text-gray-500 text-sm">{{ item.create_time }}</td>
              <td class="text-center">
                <div class="action-buttons">
                  <button class="action-btn primary" @click="editPrompt(item.id)" title="编辑">
                    <Edit :size="14" />
                  </button>
                  <button class="action-btn danger" @click="handleDeletePrompt(item.id)" title="删除">
                    <Trash2 :size="14" />
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>

        <div v-if="!loading.prompts && promptList.length > 0 && pagination.total_pages > 1" class="pagination">
          <button 
            class="page-btn" 
            :disabled="pagination.page <= 1" 
            @click="goToPage(pagination.page - 1)"
          >
            <ChevronLeft :size="16" />
          </button>
          <span class="page-info">
            {{ pagination.page }} / {{ pagination.total_pages }}
          </span>
          <button 
            class="page-btn" 
            :disabled="pagination.page >= pagination.total_pages" 
            @click="goToPage(pagination.page + 1)"
          >
            <ChevronRight :size="16" />
          </button>
        </div>
      </div>
    </section>
  </div>
</template>

<style scoped>
.profile-view {
  height: 100%;
  overflow-y: auto;
  padding: 32px;
  background-color: var(--bg-primary);
}

.page-header {
  margin-bottom: 32px;
}

.title-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 8px;
}

.page-title {
  font-size: 24px;
  font-weight: 700;
  color: var(--gray-900);
  margin: 0;
}

.page-desc {
  font-size: 14px;
  color: var(--gray-500);
  margin: 0;
}

.refresh-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  border-radius: var(--radius-md);
  font-size: 13px;
  font-weight: 500;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  color: var(--gray-600);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.refresh-btn:hover:not(:disabled) {
  background: var(--primary-light);
  border-color: var(--primary-200);
  color: var(--primary-600);
}

.refresh-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

.stats-overview {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 16px;
  margin-bottom: 32px;
}

.stat-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-subtle);
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 8px;
  transition: all var(--transition-normal);
  box-shadow: var(--shadow-sm);
}

.stat-card:hover {
  border-color: var(--primary-light);
  box-shadow: var(--shadow-md);
  transform: translateY(-2px);
}

.stat-card-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.stat-icon {
  width: 40px;
  height: 40px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
}

.stat-icon.blue { background: var(--primary-light); color: var(--primary-600); }
.stat-icon.teal { background: #CCFBF1; color: #0D9488; }
.stat-icon.orange { background: #FEF3C7; color: #D97706; }
.stat-icon.purple { background: #F3E8FF; color: #9333EA; }
.stat-icon.indigo { background: #E0E7FF; color: #4F46E5; }
.stat-icon.pink { background: #FCE7F3; color: #DB2777; }

.stat-value {
  font-size: 28px;
  font-weight: 700;
  color: var(--gray-900);
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 36px;
}

.stat-label {
  font-size: 13px;
  color: var(--gray-500);
  text-align: center;
}

.activity-section {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-subtle);
  margin-bottom: 32px;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.section-header {
  padding: 16px 24px;
  border-bottom: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.section-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--gray-900);
  display: flex;
  align-items: center;
  margin: 0;
}

.count-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 24px;
  height: 20px;
  padding: 0 8px;
  margin-left: 8px;
  background: var(--primary-light);
  color: var(--primary-600);
  border-radius: 10px;
  font-size: 12px;
  font-weight: 600;
}

.activity-list {
  padding: 0 24px;
}

.activity-item {
  padding: 16px 0;
  border-bottom: 1px solid var(--border-subtle);
  display: flex;
  align-items: flex-start;
  gap: 16px;
}

.activity-item:last-child {
  border-bottom: none;
}

.activity-icon {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.activity-icon.create { background: var(--primary-light); color: var(--primary-600); }
.activity-icon.like { background: #FEF3C7; color: #D97706; }
.activity-icon.favorite { background: #CCFBF1; color: #0D9488; }
.activity-icon.share { background: #F3E8FF; color: #9333EA; }
.activity-icon.copy { background: #E0E7FF; color: #4F46E5; }

.activity-content {
  flex: 1;
}

.activity-text {
  font-size: 14px;
  color: var(--gray-900);
  margin-bottom: 4px;
}

.activity-time {
  font-size: 12px;
  color: var(--gray-500);
}

.prompt-details {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-subtle);
  margin-bottom: 32px;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.table-container {
  padding: 0 24px 24px;
  overflow-x: auto;
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 48px 24px;
  color: var(--gray-500);
  gap: 12px;
}

.empty-icon {
  opacity: 0.3;
}

.create-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 10px 20px;
  background: var(--primary-600);
  color: white;
  border: none;
  border-radius: var(--radius-md);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.create-btn:hover {
  background: var(--primary-700);
}

table {
  width: 100%;
  border-collapse: collapse;
}

th {
  padding: 12px 16px;
  text-align: left;
  font-size: 13px;
  font-weight: 600;
  color: var(--gray-500);
  text-transform: uppercase;
  letter-spacing: 0.05em;
  border-bottom: 1px solid var(--border-subtle);
}

th.text-center { text-align: center; }
th.text-left { text-align: left; }

td {
  padding: 16px;
  font-size: 14px;
  color: var(--gray-900);
  border-bottom: 1px solid var(--border-subtle);
}

tr:last-child td {
  border-bottom: none;
}

.font-medium { font-weight: 500; }
.text-gray-800 { color: var(--gray-900); }
.text-gray-500 { color: var(--gray-500); }
.text-sm { font-size: 13px; }
.text-center { text-align: center; }

.prompt-title {
  display: flex;
  align-items: center;
  gap: 8px;
}

.template-badge {
  display: inline-flex;
  align-items: center;
  padding: 2px 8px;
  background: #CCFBF1;
  color: #0D9488;
  border-radius: 4px;
  font-size: 11px;
  font-weight: 500;
}

.action-buttons {
  display: flex;
  gap: 8px;
  justify-content: center;
}

.action-btn {
  padding: 6px 10px;
  border-radius: var(--radius-sm);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
  display: flex;
  align-items: center;
  gap: 4px;
  border: none;
}

.action-btn.primary {
  background: var(--primary-light);
  color: var(--primary-600);
}

.action-btn.primary:hover {
  background: var(--primary-600);
  color: white;
}

.action-btn.danger {
  background: #FEE2E2;
  color: #DC2626;
}

.action-btn.danger:hover {
  background: #DC2626;
  color: white;
}

.pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid var(--border-subtle);
}

.page-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border-radius: var(--radius-md);
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  color: var(--gray-600);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.page-btn:hover:not(:disabled) {
  background: var(--primary-light);
  border-color: var(--primary-200);
  color: var(--primary-600);
}

.page-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
}

.page-info {
  font-size: 14px;
  color: var(--gray-600);
  font-weight: 500;
}

@media (max-width: 768px) {
  .profile-view {
    padding: 20px;
  }

  .stats-overview {
    grid-template-columns: repeat(2, 1fr);
  }

  .table-container {
    padding: 0 16px 16px;
  }
  
  th, td {
    padding: 12px 8px;
  }

  .action-buttons {
    flex-direction: column;
    gap: 4px;
  }
}
</style>

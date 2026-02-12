<script setup lang="ts">
import { ref } from 'vue'
import { 
  FileText, 
  Heart, 
  ThumbsUp, 
  Share2, 
  TrendingUp, 
  Activity, 
  Plus, 
  Edit, 
  Download
} from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'

// Mock Data for Stats
const stats = [
  { 
    id: 1, 
    label: '总提示词数', 
    value: 42, 
    trend: '+12%', 
    trendUp: true, 
    icon: FileText, 
    colorClass: 'blue' 
  },
  { 
    id: 2, 
    label: '收藏提示词', 
    value: 18, 
    trend: '+8%', 
    trendUp: true, 
    icon: Heart, 
    colorClass: 'teal' 
  },
  { 
    id: 3, 
    label: '获赞总数', 
    value: 25, 
    trend: '+15%', 
    trendUp: true, 
    icon: ThumbsUp, 
    colorClass: 'orange' 
  },
  { 
    id: 4, 
    label: '分享次数', 
    value: 12, 
    trend: '+5%', 
    trendUp: true, 
    icon: Share2, 
    colorClass: 'purple' 
  }
]

// Mock Data for Activities
const activities = [
  {
    id: 1,
    type: 'create',
    text: '创建了新的提示词：',
    highlight: '产品营销文案生成器',
    time: '2小时前',
    icon: Plus
  },
  {
    id: 2,
    type: 'update',
    text: '更新了提示词：',
    highlight: 'SEO关键词分析工具',
    time: '5小时前',
    icon: Edit
  },
  {
    id: 3,
    type: 'share',
    text: '分享了提示词：',
    highlight: '社交媒体内容规划器',
    time: '1天前',
    icon: Share2
  }
]

// Mock Data for Prompt Table
const promptDetails = [
  {
    id: 1,
    name: '产品营销文案生成器',
    likes: 8,
    favorites: 5,
    uses: 23,
    createdAt: '2024-01-15 14:30'
  },
  {
    id: 2,
    name: 'SEO关键词分析工具',
    likes: 12,
    favorites: 7,
    uses: 18,
    createdAt: '2024-01-14 09:15'
  },
  {
    id: 3,
    name: '社交媒体内容规划器',
    likes: 5,
    favorites: 3,
    uses: 15,
    createdAt: '2024-01-13 16:45'
  },
  {
    id: 4,
    name: '数据分析报告生成器',
    likes: 10,
    favorites: 6,
    uses: 20,
    createdAt: '2024-01-12 11:20'
  }
]

const editPrompt = (id: number) => {
  // Mock edit
  console.log('Edit prompt', id)
}

</script>

<template>
  <div class="profile-view">
    <!-- Header -->
    <header class="page-header">
      <div class="header-content">
        <h1 class="page-title">我的个人中心</h1>
        <p class="page-desc">查看您的使用统计和活动记录</p>
      </div>
    </header>

    <!-- Stats Overview -->
    <section class="stats-overview">
      <div v-for="stat in stats" :key="stat.id" class="stat-card">
        <div class="stat-card-header">
          <div class="stat-icon" :class="stat.colorClass">
            <component :is="stat.icon" :size="20" />
          </div>
        </div>
        <div class="stat-value">{{ stat.value }}</div>
        <div class="stat-label">{{ stat.label }}</div>
        <div class="stat-trend" :class="{ positive: stat.trendUp, negative: !stat.trendUp }">
          <TrendingUp :size="12" />
          {{ stat.trend }} 本月
        </div>
      </div>
    </section>

    <!-- Activity Section -->
    <section class="activity-section">
      <div class="section-header">
        <h2 class="section-title">
          <Activity :size="18" class="mr-2 inline-block" />
          最近活动
        </h2>
        <a href="#" class="section-action">查看全部</a>
      </div>
      <div class="activity-list">
        <div v-for="activity in activities" :key="activity.id" class="activity-item">
          <div class="activity-icon" :class="activity.type">
            <component :is="activity.icon" :size="16" />
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

    <!-- Prompt Details Table -->
    <section class="prompt-details">
      <div class="section-header">
        <h2 class="section-title">
          <FileText :size="18" class="mr-2 inline-block" />
          提示词明细表
        </h2>
        <button class="section-action-btn">
          <Download :size="14" />
          导出数据
        </button>
      </div>
      <div class="table-container">
        <table>
          <thead>
            <tr>
              <th class="text-left">提示词名称</th>
              <th class="text-center">点赞数</th>
              <th class="text-center">收藏数</th>
              <th class="text-center">应用数</th>
              <th class="text-center">创建时间</th>
              <th class="text-center">操作</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="item in promptDetails" :key="item.id">
              <td class="font-medium text-gray-800">{{ item.name }}</td>
              <td class="text-center">{{ item.likes }}</td>
              <td class="text-center">{{ item.favorites }}</td>
              <td class="text-center">{{ item.uses }}</td>
              <td class="text-center text-gray-500 text-sm">{{ item.createdAt }}</td>
              <td class="text-center">
                <div class="action-buttons">
                  <button class="action-btn primary" @click="editPrompt(item.id)" title="编辑">
                    <Edit :size="14" />
                    编辑
                  </button>
                  <CopyButton :text="item.name" label="复制" />
                </div>
              </td>
            </tr>
          </tbody>
        </table>
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

/* Page Header */
.page-header {
  margin-bottom: 32px;
}

.page-title {
  font-size: 24px;
  font-weight: 700;
  color: var(--gray-900);
  margin-bottom: 8px;
}

.page-desc {
  font-size: 14px;
  color: var(--gray-500);
}

/* Stats Overview */
.stats-overview {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
  gap: 20px;
  margin-bottom: 32px;
}

.stat-card {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-subtle);
  padding: 24px;
  display: flex;
  flex-direction: column;
  gap: 12px;
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
  width: 48px;
  height: 48px;
  border-radius: var(--radius-md);
  display: flex;
  align-items: center;
  justify-content: center;
}

/* Stat Icon Colors */
.stat-icon.blue { background: var(--primary-light); color: var(--primary-600); }
.stat-icon.teal { background: #CCFBF1; color: #0D9488; } /* Teal-100, Teal-600 */
.stat-icon.orange { background: #FEF3C7; color: #D97706; } /* Amber-100, Amber-600 */
.stat-icon.purple { background: #F3E8FF; color: #9333EA; } /* Purple-100, Purple-600 */

.stat-value {
  font-size: 32px;
  font-weight: 700;
  color: var(--gray-900);
}

.stat-label {
  font-size: 14px;
  color: var(--gray-500);
}

.stat-trend {
  font-size: 12px;
  font-weight: 500;
  display: flex;
  align-items: center;
  gap: 4px;
}

.stat-trend.positive { color: var(--success); }
.stat-trend.negative { color: var(--error); }

/* Activity Section */
.activity-section {
  background: var(--bg-surface);
  border-radius: var(--radius-lg);
  border: 1px solid var(--border-subtle);
  margin-bottom: 32px;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
}

.section-header {
  padding: 20px 24px;
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
}

.section-action, .section-action-btn {
  font-size: 13px;
  color: var(--primary-600);
  text-decoration: none;
  font-weight: 500;
  transition: color var(--transition-fast);
  background: none;
  border: none;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 6px;
}

.section-action:hover, .section-action-btn:hover {
  color: var(--primary-700);
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
.activity-icon.update { background: #CCFBF1; color: #0D9488; }
.activity-icon.share { background: #FEF3C7; color: #D97706; }

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

/* Prompt Details Table */
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

.action-buttons {
  display: flex;
  gap: 8px;
  justify-content: center;
}

.action-btn {
  padding: 6px 12px;
  border-radius: var(--radius-sm);
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
  display: flex;
  align-items: center;
  gap: 4px;
}

.action-btn.primary {
  background: var(--primary-light);
  color: var(--primary-600);
  border: 1px solid transparent;
}

.action-btn.primary:hover {
  background: var(--primary-600);
  color: white;
}

.action-btn.secondary {
  background: transparent;
  color: var(--gray-500);
  border: 1px solid var(--border-subtle);
}

.action-btn.secondary:hover {
  background: var(--bg-primary);
  color: var(--gray-900);
  border-color: var(--gray-500);
}

/* Responsive */
@media (max-width: 768px) {
  .main-content {
    margin-left: 0;
    width: 100%;
    padding: 20px;
  }
  
  .main-content.collapsed {
    margin-left: 0;
    width: 100%;
  }

  .stats-overview {
    grid-template-columns: 1fr;
  }

  .table-container {
    padding: 0 16px 16px;
  }
  
  th, td {
    padding: 12px 8px;
  }
}
</style>

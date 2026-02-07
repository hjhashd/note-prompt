<script setup lang="ts">
import { ref } from 'vue'
import Sidebar from '@/components/layout/Sidebar.vue'
import { 
  Users, 
  FileText, 
  Heart, 
  Activity, 
  TrendingUp,
  Eye,
  Edit
} from 'lucide-vue-next'

const isCollapsed = ref(false)

const toggleSidebar = () => {
  isCollapsed.value = !isCollapsed.value
}

// Stats Data
const stats = [
  { 
    id: 1, 
    title: '总用户数', 
    value: '1,248', 
    change: '+12%', 
    isPositive: true, 
    icon: Users, 
    type: 'total' 
  },
  { 
    id: 2, 
    title: '提示词总数', 
    value: '3,856', 
    change: '+24%', 
    isPositive: true, 
    icon: FileText, 
    type: 'collections' 
  },
  { 
    id: 3, 
    title: '总点赞数', 
    value: '12.5k', 
    change: '+8%', 
    isPositive: true, 
    icon: Heart, 
    type: 'likes' 
  },
  { 
    id: 4, 
    title: '总使用次数', 
    value: '45.2k', 
    change: '+32%', 
    isPositive: true, 
    icon: Activity, 
    type: 'uses' 
  }
]

// Mock Data for Graph Controls
const selectedUser = ref('all')
const graphType = ref('interaction')

// Leaderboard Data
const topUsers = [
  { id: 1, name: 'Alex Johnson', email: 'alex.j@example.com', score: 1250, rank: 1 },
  { id: 2, name: 'Sarah Williams', email: 'sarah.w@example.com', score: 980, rank: 2 },
  { id: 3, name: 'Michael Brown', email: 'm.brown@example.com', score: 850, rank: 3 },
  { id: 4, name: 'Emily Davis', email: 'emily.d@example.com', score: 720, rank: 4 },
  { id: 5, name: 'David Wilson', email: 'david.w@example.com', score: 650, rank: 5 },
]

const popularPrompts = [
  { id: 1, title: '产品营销文案生成器', author: 'Alex Johnson', score: 450, rank: 1 },
  { id: 2, title: 'SEO关键词分析工具', author: 'Sarah Williams', score: 380, rank: 2 },
  { id: 3, title: '代码审查助手', author: 'Michael Brown', score: 320, rank: 3 },
  { id: 4, title: '周报生成器', author: 'Emily Davis', score: 290, rank: 4 },
  { id: 5, title: '邮件回复助手', author: 'David Wilson', score: 250, rank: 5 },
]

// Users Table Data
const usersList = [
  { id: 1, name: 'Alex Johnson', email: 'alex.j@example.com', role: '高级用户', status: 'Active', joinDate: '2023-10-15' },
  { id: 2, name: 'Sarah Williams', email: 'sarah.w@example.com', role: '普通用户', status: 'Active', joinDate: '2023-11-02' },
  { id: 3, name: 'Michael Brown', email: 'm.brown@example.com', role: '普通用户', status: 'Inactive', joinDate: '2023-11-20' },
  { id: 4, name: 'Emily Davis', email: 'emily.d@example.com', role: '高级用户', status: 'Active', joinDate: '2023-12-05' },
  { id: 5, name: 'David Wilson', email: 'david.w@example.com', role: '普通用户', status: 'Active', joinDate: '2024-01-10' },
]

// Helper for Rank Class
const getRankClass = (rank: number) => {
  if (rank === 1) return 'first'
  if (rank === 2) return 'second'
  if (rank === 3) return 'third'
  return 'other'
}

</script>

<template>
  <div class="app-container">
    <Sidebar :collapsed="isCollapsed" @toggle="toggleSidebar" />
    
    <main class="main-content" :class="{ collapsed: isCollapsed }">
      <!-- Page Header -->
      <header class="page-header">
        <h1 class="page-title">管理员面板</h1>
        <p class="page-subtitle">概览系统状态、用户活动及内容表现</p>
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
            {{ stat.change }} 较上月
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
          <!-- Mock SVG Graph -->
          <svg viewBox="0 0 800 400" class="relationship-graph">
            <!-- Links -->
            <g class="links">
              <line x1="400" y1="200" x2="250" y2="150" class="link" />
              <line x1="400" y1="200" x2="550" y2="150" class="link" />
              <line x1="400" y1="200" x2="400" y2="300" class="link" />
              <line x1="250" y1="150" x2="150" y2="200" class="link" />
              <line x1="250" y1="150" x2="200" y2="80" class="link" />
              <line x1="550" y1="150" x2="650" y2="200" class="link" />
              <line x1="550" y1="150" x2="600" y2="80" class="link" />
            </g>
            
            <!-- Nodes -->
            <g class="nodes">
              <!-- Central Node -->
              <circle cx="400" cy="200" r="30" class="node node-hub" />
              <text x="400" y="205" text-anchor="middle" class="node-label-text">System</text>
              
              <!-- Level 1 Nodes -->
              <circle cx="250" cy="150" r="20" class="node node-user" />
              <circle cx="550" cy="150" r="20" class="node node-user" />
              <circle cx="400" cy="300" r="20" class="node node-prompt" />
              
              <!-- Level 2 Nodes -->
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
            <div class="leaderboard-list">
              <div v-for="user in topUsers" :key="user.id" class="leaderboard-item">
                <div class="leaderboard-rank" :class="getRankClass(user.rank)">{{ user.rank }}</div>
                <div class="leaderboard-info">
                  <div class="info-primary">{{ user.name }}</div>
                  <div class="info-secondary">{{ user.email }}</div>
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
            <div class="leaderboard-list">
              <div v-for="prompt in popularPrompts" :key="prompt.id" class="leaderboard-item">
                <div class="leaderboard-rank" :class="getRankClass(prompt.rank)">{{ prompt.rank }}</div>
                <div class="leaderboard-info">
                  <div class="info-primary">{{ prompt.title }}</div>
                  <div class="info-secondary">By {{ prompt.author }}</div>
                </div>
                <div class="leaderboard-score">{{ prompt.score }} uses</div>
              </div>
            </div>
          </div>
        </div>
      </section>

      <!-- Users Table -->
      <section class="users-section">
        <div class="section-header">
          <h2 class="section-title">用户管理</h2>
        </div>
        <div class="table-card">
          <div class="table-container">
            <table>
              <thead>
                <tr>
                  <th>用户姓名</th>
                  <th>邮箱地址</th>
                  <th>角色</th>
                  <th>状态</th>
                  <th>加入时间</th>
                  <th>操作</th>
                </tr>
              </thead>
              <tbody>
                <div v-if="false"></div> <!-- Vue hack for clean HTML structure if needed, but table structure is rigid -->
                <tr v-for="user in usersList" :key="user.id">
                  <td class="font-medium">{{ user.name }}</td>
                  <td class="text-secondary">{{ user.email }}</td>
                  <td>
                    <span class="badge" :class="user.role === '高级用户' ? 'premium' : 'standard'">
                      {{ user.role }}
                    </span>
                  </td>
                  <td>
                    <span class="status-dot" :class="user.status.toLowerCase()"></span>
                    {{ user.status }}
                  </td>
                  <td class="text-secondary">{{ user.joinDate }}</td>
                  <td>
                    <div class="action-buttons">
                      <button class="action-btn" title="查看详情"><Eye :size="14" /></button>
                      <button class="action-btn" title="编辑用户"><Edit :size="14" /></button>
                    </div>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

    </main>
  </div>
</template>

<style scoped>
.app-container {
  display: flex;
  min-height: 100vh;
  background-color: var(--bg-primary);
}

.main-content {
  flex: 1;
  margin-left: var(--sidebar-width);
  padding: 32px;
  transition: margin-left var(--transition-normal);
  width: calc(100% - var(--sidebar-width));
  background-color: var(--bg-primary);
}

.main-content.collapsed {
  margin-left: var(--sidebar-width-collapsed);
  width: calc(100% - var(--sidebar-width-collapsed));
}

/* Page Header */
.page-header {
  margin-bottom: 32px;
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
}

.section-title {
  font-size: 20px;
  font-weight: 600;
  color: var(--gray-900);
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
  color: #4f46e5;
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
  width: 28px;
  height: 28px;
  display: flex;
  align-items: center;
  justify-content: center;
  border: 1px solid var(--border-subtle);
  background: transparent;
  border-radius: var(--radius-sm);
  color: var(--gray-500);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.action-btn:hover {
  background: var(--bg-primary);
  color: var(--primary-600);
  border-color: var(--primary-light);
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

  .stats-grid {
    grid-template-columns: 1fr;
  }

  .leaderboards-grid {
    grid-template-columns: 1fr;
  }
}
</style>

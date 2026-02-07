<script setup lang="ts">
const recentPrompts = [
  { id: 1, title: 'SEO 博客生成器', icon: '📝', tags: ['business', 'marketing'] },
  { id: 2, title: 'Python 代码助手', icon: '🐍', tags: ['coding'] },
  { id: 3, title: 'Midjourney 提示词', icon: '🎨', tags: ['creative'] }
]
</script>

<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <div class="search-box">
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="11" cy="11" r="8"></circle>
          <line x1="21" y1="21" x2="16.65" y2="16.65"></line>
        </svg>
        <input type="text" placeholder="搜索标签...">
      </div>
    </div>

    <div class="sidebar-content">
      <div class="sidebar-section">
        <div class="sidebar-section-title">最近使用</div>
        <div class="prompt-list">
          <div v-for="prompt in recentPrompts" :key="prompt.id" class="prompt-card" :class="{ active: prompt.id === 1 }">
            <div class="prompt-card-header">
              <div class="prompt-card-title">
                <span class="prompt-card-icon">{{ prompt.icon }}</span>
                <span>{{ prompt.title }}</span>
              </div>
            </div>
            <div class="prompt-card-tags">
              <span v-for="tag in prompt.tags" :key="tag" class="tag-chip" :class="tag">
                {{ tag }}
              </span>
            </div>
          </div>
        </div>
      </div>

      <div class="sidebar-section">
        <div class="sidebar-section-title">标签目录</div>
        <div class="template-tree">
          <!-- Mock Tree Items -->
          <div class="tree-item">
            <div class="tree-item-header">
              <svg class="tree-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 18l6-6-6-6"/>
              </svg>
              <span class="tree-item-name">写作辅助</span>
            </div>
          </div>
           <div class="tree-item">
            <div class="tree-item-header">
              <svg class="tree-icon" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M9 18l6-6-6-6"/>
              </svg>
              <span class="tree-item-name">代码开发</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  </aside>
</template>

<style scoped>
.sidebar {
  /* width: 280px;  Handled by parent */
  width: 100%;
  flex-shrink: 0;
  background: transparent; /* Parent card has background */
  /* border-right: 1px solid var(--border-light); Removed */
  display: flex;
  flex-direction: column;
  position: relative;
  height: 100%;
}

/* Removed collapsed styles as they are no longer used */

/* .sidebar-toggle removed in previous step */

.sidebar-header {
  padding: 20px;
  /* border-bottom: 1px solid var(--border-light); Optional: keep or remove for cleaner look */
}

.search-box {
  position: relative;
}

.search-box input {
  width: 100%;
  padding: 10px 16px 10px 40px;
  background: var(--bg-primary); /* Contrast against white card */
  border: 1px solid var(--border-subtle);
  border-radius: 24px; /* Pill shape */
  font-size: 14px;
  transition: all 0.2s;
}

.search-box input:focus {
  background: var(--bg-surface);
  border-color: var(--primary-600);
  box-shadow: 0 0 0 2px var(--primary-light);
  outline: none;
}

.search-box svg {
  position: absolute;
  left: 12px;
  top: 50%;
  transform: translateY(-50%);
  width: 18px;
  height: 18px;
  color: var(--gray-400);
}

.sidebar-content {
  flex: 1;
  overflow-y: auto;
  padding: 0 12px 20px;
}

.sidebar-section {
  margin-bottom: 24px;
}

.sidebar-section-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--gray-500);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 12px;
  padding: 0 8px;
}

.prompt-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.prompt-card {
  padding: 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: var(--shadow-sm);
}

.prompt-card:hover {
  border-color: var(--primary-600);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.prompt-card.active {
  background: var(--primary-light);
  border-color: var(--primary-600);
}

.prompt-card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 8px;
}

.prompt-card-title {
  font-weight: 500;
  font-size: 14px;
  color: var(--gray-900);
  display: flex;
  align-items: center;
  gap: 8px;
}

.prompt-card-icon {
  font-size: 16px;
}

.prompt-card-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 4px;
}

.tag-chip {
  font-size: 10px;
  padding: 2px 6px;
  background: var(--bg-primary);
  border-radius: 4px;
  color: var(--gray-600);
}

.tag-chip.business { color: #d97706; background: #fef3c7; }
.tag-chip.marketing { color: #2563eb; background: #dbeafe; }
.tag-chip.coding { color: #059669; background: #d1fae5; }
.tag-chip.creative { color: #db2777; background: #fce7f3; }

/* Tree Styles */
.tree-item {
  padding: 8px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  color: var(--gray-600);
  transition: all 0.2s;
}

.tree-item:hover {
  background: var(--bg-primary);
  color: var(--gray-900);
}

.tree-item-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
}
</style>

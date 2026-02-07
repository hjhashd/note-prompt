<script setup lang="ts">
import { ref, watch } from 'vue'

const props = defineProps<{
  title: string
  mode: string
}>()

const emit = defineEmits<{
  (e: 'update:title', value: string): void
  (e: 'update:mode', value: string): void
  (e: 'toggle-chat'): void
}>()

const localMode = ref(props.mode)

watch(() => props.mode, (newVal) => {
  localMode.value = newVal
})

const setMode = (mode: string) => {
  localMode.value = mode
  emit('update:mode', mode)
}
</script>

<template>
  <header class="workspace-header">
    <div class="header-left">
      <div class="version-badge">V1.2</div>
    </div>

    <div class="mode-toggle">
      <button 
        class="mode-btn" 
        :class="{ active: localMode === 'dialogue' }"
        @click="setMode('dialogue')"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
        </svg>
        对话
      </button>
      <button 
        class="mode-btn" 
        :class="{ active: localMode === 'expert' }"
        @click="setMode('expert')"
      >
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <polyline points="16 18 22 12 16 6"></polyline>
          <polyline points="8 6 2 12 8 18"></polyline>
        </svg>
        专业
      </button>
    </div>

    <div class="header-right">
      <button class="header-btn" @click="emit('toggle-chat')">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M21 11.5a8.38 8.38 0 0 1-.9 3.8 8.5 8.5 0 0 1-7.6 4.7 8.38 8.38 0 0 1-3.8-.9L3 21l1.9-5.7a8.38 8.38 0 0 1-.9-3.8 8.5 8.5 0 0 1 4.7-7.6 8.38 8.38 0 0 1 3.8-.9h.5a8.48 8.48 0 0 1 8 8v.5z"></path>
        </svg>
        AI 助手
      </button>
      <button class="header-btn primary">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"></path>
          <polyline points="17 21 17 13 7 13 7 21"></polyline>
          <polyline points="7 3 7 8 15 8"></polyline>
        </svg>
        保存
      </button>
    </div>
  </header>
</template>

<style scoped>
.workspace-header {
    height: 64px;
    padding: 0 16px; /* Increased padding */
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: transparent;
    border-bottom: 1px solid rgba(0,0,0,0.05); /* Subtle divider */
    margin-bottom: 8px; /* Add some space below header */
    position: relative;
}

.header-left {
    display: flex;
    align-items: center;
    gap: 16px;
}

.version-badge {
    padding: 2px 8px;
    background: var(--bg-surface); /* White badge */
    border-radius: 12px;
    font-size: 12px;
    font-weight: 500;
    color: var(--text-secondary);
    box-shadow: var(--shadow-sm);
    border: 1px solid var(--border-subtle);
}

.mode-toggle {
    display: flex;
    background: var(--bg-surface);
    padding: 4px;
    border-radius: 20px; /* Pill shape */
    gap: 4px;
    border: 1px solid var(--border-subtle);
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
}

.mode-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    border: none;
    background: transparent;
    border-radius: 16px;
    font-size: 14px;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all var(--transition-fast);
}

.mode-btn.active {
    background: var(--bg-surface);
    color: var(--text-primary);
    box-shadow: var(--shadow-sm);
    font-weight: 500;
}

.header-right {
    display: flex;
    align-items: center;
    gap: 12px;
}

.header-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    border: 1px solid transparent;
    background: var(--bg-surface);
    border-radius: 24px; /* Pill shape */
    font-size: 14px;
    color: var(--text-primary);
    cursor: pointer;
    transition: all var(--transition-fast);
    box-shadow: var(--shadow-sm);
}

.header-btn:hover {
    background: var(--bg-primary);
    transform: translateY(-1px);
    box-shadow: var(--shadow-md);
}

.header-btn.primary {
    background: var(--text-primary); /* Black button like NotebookLM */
    color: var(--text-inverse);
}

.header-btn.primary:hover {
    background: #000000;
    box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
</style>

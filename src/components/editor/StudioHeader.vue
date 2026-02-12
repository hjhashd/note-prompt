<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRouter } from 'vue-router'
import { ArrowLeft } from 'lucide-vue-next'

const props = defineProps<{
  title: string
  mode: string
}>()

const emit = defineEmits<{
  (e: 'update:title', value: string): void
  (e: 'update:mode', value: string): void
}>()

const router = useRouter()
const localMode = ref(props.mode)

watch(() => props.mode, (newVal) => {
  localMode.value = newVal
})

const setMode = (mode: string) => {
  localMode.value = mode
  emit('update:mode', mode)
}

const goBack = () => {
  router.back()
}
</script>

<template>
  <header class="workspace-header">
    <div class="header-left">
      <button class="back-btn" @click="goBack" title="返回上一页">
        <ArrowLeft :size="20" />
      </button>
    </div>

    <div class="header-center">
      <h1 class="header-title">{{ title }}</h1>
    </div>

    <div class="header-right">
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
    </div>
  </header>
</template>

<style scoped>
.workspace-header {
    height: 64px;
    padding: 0 24px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    background: transparent;
    border-bottom: 1px solid rgba(0,0,0,0.05);
    margin-bottom: 8px;
    position: relative;
}

.header-left {
    display: flex;
    align-items: center;
    gap: 16px;
    min-width: 0;
    flex: 0 0 auto;
}

.back-btn {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border: 1px solid var(--border-subtle);
    background: var(--bg-surface);
    border-radius: 50%;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all var(--transition-fast);
    box-shadow: var(--shadow-sm);
}

.back-btn:hover {
    background: var(--bg-secondary);
    color: var(--text-primary);
    border-color: var(--border-default);
    transform: translateX(-2px);
}

.header-center {
    position: absolute;
    left: 50%;
    transform: translateX(-50%);
    display: flex;
    align-items: center;
    justify-content: center;
    max-width: 40%;
}

.header-title {
    font-size: 16px;
    font-weight: 600;
    color: var(--text-primary);
    margin: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    text-align: center;
}

.header-right {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    flex: 0 0 auto;
    gap: 12px;
}

.mode-toggle {
    display: flex;
    background: var(--bg-secondary);
    padding: 4px;
    border-radius: 24px;
    gap: 4px;
    border: 1px solid rgba(0,0,0,0.04);
}

.mode-btn {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 6px 16px;
    border: none;
    background: transparent;
    border-radius: 20px;
    font-size: 13px;
    font-weight: 500;
    color: var(--text-secondary);
    cursor: pointer;
    transition: all 0.3s cubic-bezier(0.25, 0.8, 0.25, 1);
}

.mode-btn:hover {
    color: var(--text-primary);
    background: rgba(255,255,255,0.5);
}

.mode-btn.active {
    background: #ffffff;
    color: var(--primary);
    box-shadow: 0 2px 8px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04);
    font-weight: 600;
}

/* Specific colors for different modes to be distinctive */
.mode-btn:first-child.active {
    color: #3b82f6; /* Blue for Dialogue */
}

.mode-btn:last-child.active {
    color: #8b5cf6; /* Purple for Expert */
}
</style>

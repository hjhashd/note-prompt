<script setup lang="ts">
import { computed } from 'vue'
import { Copy, Sparkles, MessageSquare } from 'lucide-vue-next'
import type { PromptItem } from '@/types/prompt'
import CopyButton from '@/components/common/CopyButton.vue'

const props = defineProps<{
  prompt: PromptItem
  compact?: boolean
}>()

const emit = defineEmits<{
  (e: 'use', content: string): void
  (e: 'optimize', content: string): void
}>()

const getTagColor = (tag: string) => {
  const t = tag.toLowerCase()
  if (['python', 'vue', 'js', 'code'].some(k => t.includes(k))) return 'text-blue-600 bg-blue-50 border-blue-200'
  if (['writing', '文案', '写作'].some(k => t.includes(k))) return 'text-purple-600 bg-purple-50 border-purple-200'
  if (['image', 'drawing', '绘画'].some(k => t.includes(k))) return 'text-pink-600 bg-pink-50 border-pink-200'
  return 'text-gray-600 bg-gray-50 border-gray-200'
}
</script>

<template>
  <div v-if="compact" class="prompt-ref-compact">
    <div class="compact-content">
      {{ prompt.content }}
    </div>
    <div class="compact-actions">
      <CopyButton :text="prompt.content || ''" size="sm" />
    </div>
  </div>
  <div v-else class="prompt-ref-card">
    <div class="card-header">
      <div class="title-section">
        <h3 class="prompt-title">{{ prompt.title }}</h3>
        <div class="tags">
          <span 
            v-for="tag in prompt.tags" 
            :key="tag"
            class="tag-badge"
            :class="getTagColor(tag)"
          >
            {{ tag }}
          </span>
        </div>
      </div>
    </div>

    <div class="card-body">
      <p v-if="prompt.description" class="description">{{ prompt.description }}</p>
      
      <div class="content-preview">
        <div class="content-header">
          <span class="label">提示词内容</span>
          <CopyButton :text="prompt.content || ''" size="sm" />
        </div>
        <div class="content-box">
          {{ prompt.content }}
        </div>
      </div>
    </div>

    <div class="card-footer">
      <button class="action-btn primary" @click="emit('use', prompt.content)">
        <MessageSquare :size="14" />
        <span>基于此对话</span>
      </button>
      <button class="action-btn secondary" @click="emit('optimize', prompt.content)">
        <Sparkles :size="14" />
        <span>帮我优化</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.prompt-ref-compact {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-width: 100%;
}

.compact-actions {
  display: flex;
  justify-content: flex-start;
  margin-top: 8px;
}

.compact-content {
  white-space: pre-wrap;
  font-size: 14px;
  line-height: 1.6;
  color: var(--text-primary);
}

.prompt-ref-card {
  background: white;
  border: 1px solid var(--border-subtle);
  border-radius: 12px;
  overflow: hidden;
  box-shadow: var(--shadow-sm);
  margin-top: 8px;
  max-width: 100%;
}

.card-header {
  padding: 16px;
  border-bottom: 1px solid var(--border-subtle);
  background: var(--bg-surface);
}

.title-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.prompt-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.tag-badge {
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 12px;
  border: 1px solid transparent;
  font-weight: 500;
}

.card-body {
  padding: 16px;
}

.description {
  font-size: 14px;
  color: var(--text-secondary);
  margin-bottom: 16px;
  line-height: 1.5;
}

.content-preview {
  background: var(--bg-surface);
  border-radius: 8px;
  border: 1px solid var(--border-subtle);
  overflow: hidden;
}

.content-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 12px;
  border-bottom: 1px solid var(--border-subtle);
  background: rgba(0, 0, 0, 0.02);
}

.label {
  font-size: 12px;
  font-weight: 500;
  color: var(--text-secondary);
}

.content-box {
  padding: 12px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-size: 13px;
  color: var(--text-primary);
  white-space: pre-wrap;
  max-height: 200px;
  overflow-y: auto;
  line-height: 1.6;
}

.card-footer {
  padding: 12px 16px;
  border-top: 1px solid var(--border-subtle);
  display: flex;
  gap: 12px;
  background: var(--bg-surface);
}

.action-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: 1px solid transparent;
}

.action-btn.primary {
  background: var(--primary);
  color: white;
}

.action-btn.primary:hover {
  background: var(--primary-hover);
}

.action-btn.secondary {
  background: white;
  border-color: var(--border-subtle);
  color: var(--text-primary);
}

.action-btn.secondary:hover {
  background: var(--bg-surface-hover);
  border-color: var(--border-hover);
}
</style>

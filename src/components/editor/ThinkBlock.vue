<script setup lang="ts">
import { ref, computed } from 'vue'
import MarkdownIt from 'markdown-it'
import { BrainCircuit, ChevronDown, ChevronUp } from 'lucide-vue-next'

const md = new MarkdownIt({
  html: true,
  linkify: true,
  breaks: true
})

const props = withDefaults(defineProps<{
  content: string
  scrollable?: boolean
}>(), {
  scrollable: false
})

const isExpanded = ref(true)

const toggleExpand = () => {
  isExpanded.value = !isExpanded.value
}

const htmlContent = computed(() => {
  return md.render(props.content)
})
</script>

<template>
  <div v-if="content" class="think-block">
    <div class="think-header" @click="toggleExpand">
      <div class="header-left">
        <BrainCircuit :size="16" class="think-icon" />
        <span class="think-title">AI 思考过程</span>
      </div>
      <button class="toggle-btn">
        <component :is="isExpanded ? ChevronUp : ChevronDown" :size="16" />
      </button>
    </div>
    <div v-show="isExpanded" class="think-content markdown-body" :class="{ scrollable }" v-html="htmlContent"></div>
  </div>
</template>

<style scoped>
@import "github-markdown-css/github-markdown.css";

.think-block {
  margin: 0 0 16px 0;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  overflow: hidden;
  transition: all 0.2s ease;
}

.think-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 10px 16px;
  background: #f1f5f9;
  border-bottom: 1px solid transparent; /* Hidden when collapsed if no border needed, but better to keep consistency */
  color: #64748b;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  user-select: none;
}

.think-block:not(.collapsed) .think-header {
  border-bottom-color: #e2e8f0;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 8px;
}

.think-icon {
  color: #8b5cf6;
}

.toggle-btn {
  background: transparent;
  border: none;
  color: #64748b;
  cursor: pointer;
  display: flex;
  align-items: center;
  padding: 4px;
  border-radius: 4px;
  transition: background-color 0.2s;
}

.toggle-btn:hover {
  background-color: #e2e8f0;
  color: #475569;
}

.think-content {
  padding: 16px;
  font-size: 14px;
  line-height: 1.6;
  color: #475569;
}

.think-content.scrollable {
  max-height: 300px;
  overflow-y: auto;
}

/* Markdown Styles */
:deep(.markdown-body) {
  max-width: none !important;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
}

:deep(.markdown-body p) {
  margin-bottom: 10px;
}

:deep(.markdown-body p:last-child) {
  margin-bottom: 0;
}

:deep(.markdown-body ul), :deep(.markdown-body ol) {
  padding-left: 20px;
  margin-bottom: 10px;
}

:deep(.markdown-body code) {
  background-color: rgba(27, 31, 35, 0.05);
  padding: 0.2em 0.4em;
  border-radius: 3px;
  font-family: SFMono-Regular, Consolas, "Liberation Mono", Menlo, monospace;
  font-size: 85%;
}

:deep(.markdown-body pre) {
  background-color: #f6f8fa;
  padding: 16px;
  border-radius: 6px;
  overflow: auto;
  margin-bottom: 10px;
}

:deep(.markdown-body pre code) {
  background-color: transparent;
  padding: 0;
  font-size: 100%;
}
</style>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted, onUpdated, h, render } from 'vue'
import MarkdownIt from 'markdown-it'
import ThinkBlock from './ThinkBlock.vue'
import CopyButton from '@/components/common/CopyButton.vue'
import 'github-markdown-css/github-markdown.css'

const props = defineProps<{
  content: string
  isStreaming?: boolean
  loading?: boolean
  showCopy?: boolean
}>()

const emit = defineEmits<{
  (e: 'stream-end'): void
}>()

const thinkBlockRef = ref<InstanceType<typeof ThinkBlock> | null>(null)
const md = new MarkdownIt({
  breaks: true,
  html: true,
  linkify: true
})

// Custom renderer for code blocks to add copy buttons
const defaultFence = md.renderer.rules.fence || function (tokens, idx, options, env, self) {
  return self.renderToken(tokens, idx, options)
}

md.renderer.rules.fence = (tokens, idx, options, env, self) => {
  const token = tokens[idx]
  const code = token.content
  const lang = token.info.trim() || 'text'
  const rendered = defaultFence(tokens, idx, options, env, self)
  
  return `
    <div class="code-block-wrapper">
      <div class="code-block-header">
        <span class="code-lang">${lang}</span>
        <div class="code-copy-placeholder" data-code="${encodeURIComponent(code)}"></div>
      </div>
      ${rendered}
    </div>
  `
}

const markdownContainer = ref<HTMLElement | null>(null)

const mountCopyButtons = () => {
  if (!markdownContainer.value || props.isStreaming) return
  
  const placeholders = markdownContainer.value.querySelectorAll('.code-copy-placeholder')
  placeholders.forEach((el) => {
    if (el.hasChildNodes()) return // Already mounted
    
    const code = decodeURIComponent((el as HTMLElement).dataset.code || '')
    const vnode = h(CopyButton, { 
      text: code,
      class: 'code-copy-btn'
    })
    render(vnode, el as HTMLElement)
  })
}

onMounted(mountCopyButtons)
onUpdated(mountCopyButtons)

// Parse content into thinking and answer parts
const parsedContent = computed(() => {
  const content = props.content || ''
  const thinkMatch = content.match(/<think>([\s\S]*?)(?:<\/think>|$)/)
  const thinking = thinkMatch ? thinkMatch[1] : ''
  const answer = content.replace(/<think>[\s\S]*?<\/think>/, '').replace(/<think>[\s\S]*/, '')
  
  return { thinking, answer }
})

// Watch for stream end to trigger collapse logic
watch(() => props.isStreaming, async (newVal, oldVal) => {
  if (oldVal === true && newVal === false) {
    // Stream just ended
    emit('stream-end')
    
    // Wait for DOM update to ensure last char is rendered
    await nextTick()
    
    // Mount copy buttons for code blocks
    mountCopyButtons()
  }
  
  // Reset collapse state when new stream starts
  if (newVal === true && oldVal === false) {
    hasCollapsedThinking.value = false
  }
})

const hasCollapsedThinking = ref(false)

// Auto-collapse thinking block when answer starts rendering
watch(() => parsedContent.value.answer, (newAnswer) => {
  if (props.isStreaming && newAnswer && newAnswer.trim().length > 0 && !hasCollapsedThinking.value) {
    if (parsedContent.value.thinking) {
      hasCollapsedThinking.value = true
      nextTick(() => {
        thinkBlockRef.value?.collapse()
      })
    }
  }
})

const htmlAnswer = computed(() => {
  return md.render(parsedContent.value.answer || '')
})
</script>

<template>
  <div class="ai-content-renderer">
    <!-- Thinking Block -->
    <ThinkBlock 
      v-if="parsedContent.thinking" 
      ref="thinkBlockRef"
      :content="parsedContent.thinking" 
    />
    
    <!-- Main Content -->
    <div class="content-wrapper">
      <div 
        ref="markdownContainer"
        class="markdown-body" 
        style="will-change: transform"
        v-html="htmlAnswer"
      ></div>
      
      <!-- Actions Bar -->
      <div v-if="parsedContent.answer && !isStreaming" class="content-actions">
        <CopyButton v-if="props.showCopy ?? true" :text="parsedContent.answer" />
        <slot name="actions"></slot>
      </div>
    </div>
    
    <!-- Loading State -->
    <div v-if="loading || (isStreaming && !parsedContent.thinking && !parsedContent.answer)" class="loading-state">
       <div class="typing-indicator">
         <span></span>
         <span></span>
         <span></span>
       </div>
       <span class="loading-text">AI 正在思考中...</span>
    </div>
  </div>
</template>

<style scoped>
.ai-content-renderer {
  display: flex;
  flex-direction: column;
  gap: 12px;
  width: 100%;
}

.content-wrapper {
  position: relative;
}

.content-actions {
  margin-top: 8px;
  display: flex;
  justify-content: flex-start;
  gap: 8px;
}

/* Always visible; designed to host multiple small actions */

.loading-state {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    padding: 4px 0;
    gap: 8px;
}

.loading-text {
    font-size: 13px;
    color: var(--text-tertiary);
    animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
}

.typing-indicator {
    display: flex;
    gap: 4px;
}

.typing-indicator span {
    width: 6px;
    height: 6px;
    background-color: var(--primary);
    border-radius: 50%;
    animation: bounce 1.4s infinite ease-in-out both;
}

.typing-indicator span:nth-child(1) { animation-delay: -0.32s; }
.typing-indicator span:nth-child(2) { animation-delay: -0.16s; }

@keyframes bounce {
    0%, 80%, 100% { transform: scale(0); }
    40% { transform: scale(1); }
}

@keyframes pulse {
    0%, 100% { opacity: 1; }
    50% { opacity: .5; }
}

/* Markdown Styles Override */
:deep(.markdown-body) {
  background: transparent !important;
  font-size: 14px;
  line-height: 1.6;
  color: var(--text-primary);
  overflow-wrap: break-word;
  word-wrap: break-word;
}

:deep(.markdown-body p) {
  margin-bottom: 1em;
}

:deep(.markdown-body p:last-child) {
  margin-bottom: 0;
}

:deep(.markdown-body pre) {
  background-color: #f6f8fa;
  border-radius: 6px;
  padding: 16px;
  margin: 0; /* Reset margin as it's now in wrapper */
  overflow-x: hidden;
  max-width: 100%;
  white-space: pre-wrap;
  word-break: break-all;
}

:deep(.markdown-body pre code) {
  white-space: pre-wrap !important;
  word-break: break-all;
}

/* Code Block Enhancements */
:deep(.code-block-wrapper) {
  position: relative;
  margin: 16px 0;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid var(--border-subtle);
  background-color: #f6f8fa;
  max-width: 100%;
}

:deep(.code-block-header) {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 12px;
  background-color: rgba(0, 0, 0, 0.03);
  border-bottom: 1px solid var(--border-subtle);
}

:deep(.code-lang) {
  font-size: 11px;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
  font-weight: 600;
  color: var(--text-tertiary);
  text-transform: lowercase;
}

/* Adjust Copy Button for Code Blocks */
:deep(.code-copy-btn) {
  height: 24px !important;
  width: 24px !important; /* Icon only */
  padding: 0 !important;
  border-radius: 4px !important;
  background: transparent !important;
  border: 1px solid transparent !important;
  color: var(--text-tertiary) !important;
}

:deep(.code-copy-btn:hover) {
  background: rgba(0, 0, 0, 0.05) !important;
  color: var(--text-secondary) !important;
}

:deep(.code-copy-btn.copied) {
  color: #137333 !important;
  background: #e6f4ea !important;
}
</style>

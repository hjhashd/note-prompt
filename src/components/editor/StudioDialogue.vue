<script setup lang="ts">
import { ref, nextTick, watch } from 'vue'
import { chatStream } from '@/api/lyf-ai'
import MarkdownIt from 'markdown-it'
import ThinkBlock from '@/components/editor/ThinkBlock.vue'
import 'github-markdown-css/github-markdown.css'

const md = new MarkdownIt({
  breaks: true,
  html: true,
  linkify: true
})

interface Message {
  id: number
  role: string
  content: string
  // 新增字段用于存储解析后的状态
  thinking?: string
  answer?: string
}

const messagesContainer = ref<HTMLElement | null>(null)
const messages = ref<Message[]>([
  { 
    id: 1, 
    role: 'ai', 
    content: '你好！我是提示词助手。你可以：\n• 描述你的需求，我会帮你构建提示词\n• 使用 @ 引用已有提示词\n• 使用 @ 提示词优化',
    answer: '你好！我是提示词助手。你可以：\n• 描述你的需求，我会帮你构建提示词\n• 使用 @ 引用已有提示词\n• 使用 @ 提示词优化'
  }
])

const input = ref('')
const isOptimizing = ref(false)

const scrollToBottom = async () => {
  await nextTick()
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight
  }
}

watch(() => messages.value.length, scrollToBottom)

// 解析思考内容和正文
const parseMessage = (content: string) => {
  const thinkMatch = content.match(/<think>([\s\S]*?)(?:<\/think>|$)/)
  const thinking = thinkMatch ? thinkMatch[1] : ''
  const answer = content.replace(/<think>[\s\S]*?<\/think>/, '').replace(/<think>[\s\S]*/, '')
  return { thinking, answer }
}

const sendMessage = async () => {
  if (!input.value.trim() || isOptimizing.value) return
  
  const prompt = input.value
  const userMsg = { id: Date.now(), role: 'user', content: prompt }
  messages.value.push(userMsg)
  
  input.value = ''
  isOptimizing.value = true
  
  // Create placeholder for AI response
  const aiMsgId = Date.now() + 1
  const aiMsg: Message = { 
    id: aiMsgId, 
    role: 'ai', 
    content: '',
    thinking: '',
    answer: ''
  }
  messages.value.push(aiMsg)
  
  const currentAiMsgIndex = messages.value.length - 1
  
  // Call real API
  await chatStream(
    { query: prompt },
    (chunk) => {
      const msg = messages.value[currentAiMsgIndex]
      if (!msg) return
      msg.content += chunk
      
      // 实时解析
      const { thinking, answer } = parseMessage(msg.content)
      msg.thinking = thinking
      msg.answer = answer
      
      scrollToBottom()
    },
    () => {
      isOptimizing.value = false
      scrollToBottom()
    },
    (error) => {
      console.error('Chat error:', error)
      const msg = messages.value[currentAiMsgIndex]
      if (msg) {
        msg.content += '\n[错误: 无法获取响应]'
      }
      isOptimizing.value = false
      scrollToBottom()
    }
  )
}
</script>

<template>
  <div class="chat-container">
    <div class="chat-messages" ref="messagesContainer">
      <div 
        v-for="msg in messages" 
        :key="msg.id" 
        class="chat-message" 
        :class="msg.role"
      >
        <div v-if="msg.role === 'ai'" class="ai-icon">
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.21 1.21 0 0 0 1.72 0L21.64 5.36a1.21 1.21 0 0 0 0-1.72Z"></path>
            <path d="m14 7 3 3"></path>
            <path d="M5 6v4"></path>
            <path d="M19 14v4"></path>
            <path d="M10 2v2"></path>
            <path d="M7 8H3"></path>
            <path d="M21 16h-4"></path>
            <path d="M11 3H9"></path>
          </svg>
        </div>
        <div class="chat-bubble">
          <!-- AI 消息渲染逻辑 -->
          <div v-if="msg.role === 'ai'" class="ai-content">
            <!-- 思考过程块 -->
            <ThinkBlock v-if="msg.thinking" :content="msg.thinking" />
            
            <!-- 正文渲染 -->
            <div class="markdown-body" v-html="md.render(msg.answer || '')"></div>
          </div>
          
          <!-- 用户消息 -->
          <div v-else style="white-space: pre-wrap;">{{ msg.content }}</div>
        </div>
      </div>
    </div>

    <div class="chat-input-area">
      <div class="chat-input-wrapper">
        <textarea 
          class="chat-input" 
          v-model="input"
          placeholder="描述你的需求，或使用 @ 引用提示词..."
          @keydown.enter.prevent="sendMessage"
        ></textarea>
        
        <div class="chat-input-actions">
          <button class="action-btn" title="优化">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"></polygon>
            </svg>
          </button>
          <button class="action-btn" title="导入/导出">
             <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M4 12v8a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-8"></path>
              <polyline points="16 6 12 2 8 6"></polyline>
              <line x1="12" y1="2" x2="12" y2="15"></line>
            </svg>
          </button>
          <button class="chat-send-btn" @click="sendMessage" :disabled="!input.trim() || isOptimizing">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <line x1="22" y1="2" x2="11" y2="13"></line>
              <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
            </svg>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.chat-container {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: transparent; /* Parent card has background */
}

.chat-messages {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  display: flex;
  flex-direction: column;
  gap: 16px;
  /* align-items: center; Removed to keep left alignment */
}

.chat-message {
  display: flex;
  width: 100%;
  max-width: 800px; /* Gemini style max-width */
  animation: fadeIn 0.3s ease;
  position: relative;
  gap: 12px;
}

.chat-message.user {
  align-self: flex-end;
  justify-content: flex-end;
}

.ai-icon {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-secondary); /* Neutral gray to match your image */
  flex-shrink: 0;
  margin-top: 4px;
}

.chat-bubble {
  padding: 12px 16px;
  border-radius: 16px;
  font-size: 14px;
  line-height: 1.6;
  position: relative;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
}

.chat-message.ai .chat-bubble {
  background: var(--bg-surface);
  color: var(--text-primary);
  border-top-left-radius: 4px;
}

.chat-message.user .chat-bubble {
  background: var(--primary);
  color: white;
  border-top-right-radius: 4px;
  border-color: transparent;
}

.chat-input-area {
  padding: 20px;
  background: transparent;
  display: flex;
  justify-content: center; /* Center the input area */
  width: 100%;
}

.chat-input-wrapper {
  position: relative;
  background: var(--bg-surface);
  border-radius: 24px;
  padding: 4px;
  transition: all 0.2s;
  border: 1px solid var(--border-subtle);
  width: 100%;
  max-width: 800px;
}

.chat-input-wrapper:focus-within {
  background: var(--bg-surface);
  box-shadow: 0 0 0 2px var(--primary-light);
  border-color: var(--primary);
}

.chat-input {
  width: 100%;
  min-height: 48px;
  max-height: 120px;
  padding: 12px 48px 12px 16px;
  border: none;
  background: transparent;
  resize: none;
  font-size: 14px;
  color: var(--text-primary);
  line-height: 1.5;
}

.chat-input:focus {
  outline: none;
}

.chat-input-actions {
  position: absolute;
  right: 8px;
  bottom: 8px;
  display: flex;
  align-items: center;
  gap: 8px;
}

.action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 32px;
  height: 32px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
}

.action-btn:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.chat-send-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  background: var(--text-primary); /* Black button like NotebookLM */
  color: white;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.2s;
}

.chat-send-btn:hover:not(:disabled) {
  transform: scale(1.05);
  background: black;
}

.chat-send-btn:disabled {
  background: var(--text-tertiary);
  cursor: not-allowed;
  opacity: 0.7;
}

/* 思考过程样式 */
.thinking-section {
  margin-bottom: 12px;
  border: 1px solid var(--border-subtle);
  border-radius: 8px;
  background-color: var(--bg-subtle);
  overflow: hidden;
}

.thinking-header {
  display: flex;
  align-items: center;
  padding: 8px 12px;
  cursor: pointer;
  user-select: none;
  background-color: rgba(0, 0, 0, 0.02);
  transition: background-color 0.2s;
}

.thinking-header:hover {
  background-color: rgba(0, 0, 0, 0.05);
}

.thinking-icon {
  margin-right: 8px;
  font-size: 14px;
}

.thinking-title {
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  flex: 1;
}

.thinking-arrow {
  font-size: 10px;
  color: var(--text-tertiary);
  transition: transform 0.2s;
}

.thinking-arrow.rotated {
  transform: rotate(180deg);
}

.thinking-body {
  padding: 12px;
  font-size: 13px;
  line-height: 1.6;
  color: var(--text-secondary);
  background-color: var(--bg-surface);
  border-top: 1px solid var(--border-subtle);
  white-space: pre-wrap;
  font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

@keyframes fadeIn {
  from { opacity: 0; transform: translateY(10px); }
  to { opacity: 1; transform: translateY(0); }
}

/* Markdown 样式覆盖 (可选) */
.markdown-body :deep(p) {
  margin-bottom: 1em;
}
.markdown-body :deep(p:last-child) {
  margin-bottom: 0;
}
</style>

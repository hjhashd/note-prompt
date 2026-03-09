<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue'
import { testStream } from '@/api/lyf-ai'
import MarkdownIt from 'markdown-it'
import ThinkBlock from './ThinkBlock.vue'
import SavePromptModal from './SavePromptModal.vue'
import { copyToClipboard } from '@/utils/clipboard'
import { useChatStore } from '@/stores/chat'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  content: string
}>()

const chatStore = useChatStore()
const { toast } = useToast()
// 使用后端实际配置的模型
const model = ref('DeepSeek-32B')
const temperature = ref(0.6)

// 测试输入内容
const testInput = ref('')

const isVariableListCollapsed = ref(false)
const thinkContent = ref('')
const realContent = ref('')
const isTesting = ref(false)
const drawerContentRef = ref<HTMLElement | null>(null)
const shouldAutoScroll = ref(true)
const showScrollButton = ref(false)
const isUserScrolling = ref(false)

// Save Modal State
const showSaveModal = ref(false)
const handleOpenSaveModal = () => {
  showSaveModal.value = true
}

const handleSavePrompt = (data: any) => {
  console.log('Saving prompt with data:', data)
  // 保存成功后的回调，数据已经在SavePromptModal中处理
  showSaveModal.value = false
}

const handlePromptSaved = (result: any) => {
  const isForked = result?.is_forked || result?.data?.is_forked
  const isUpdate = result?.is_update || result?.data?.is_update
  
  let successMsg = '提示词保存成功'
  if (isForked) {
    successMsg = '已引用并创建新提示词'
  } else if (isUpdate) {
    successMsg = '提示词更新成功'
  }
  toast(successMsg, 'success')

  // 如果会话被收敛，刷新当前会话状态
  if (result.session_status === 1) {
    // 刷新会话列表
    chatStore.loadSessions()
  }

  // 可以在这里添加其他成功后的逻辑，如跳转到提示词详情页等
  console.log('Prompt saved successfully:', result)
}

// Output queue processing
const tokenQueue: { type: 'thinking' | 'answer', text: string }[] = []
let isProcessingQueue = false
let lastRenderTime = 0
const RENDER_INTERVAL = 16 // ~60fps

const thinkBlockRef = ref<InstanceType<typeof ThinkBlock> | null>(null)

const processQueue = () => {
  if (tokenQueue.length === 0) {
    isProcessingQueue = false
    return
  }

  isProcessingQueue = true
  const now = performance.now()
  
  if (now - lastRenderTime >= RENDER_INTERVAL) {
    // Process tokens
    const bufferSize = tokenQueue.reduce((acc, item) => acc + item.text.length, 0)
    const chunkSize = bufferSize > 500 ? 50 : (bufferSize > 100 ? 10 : 2)
    
    let processedCount = 0
    let startedRealContent = false
    
    while (tokenQueue.length > 0 && processedCount < chunkSize) {
      const item = tokenQueue.shift()!
      if (item.type === 'thinking') {
        thinkContent.value += item.text
      } else {
        if (realContent.value === '') {
          startedRealContent = true
        }
        realContent.value += item.text
      }
      processedCount++
    }

    if (startedRealContent && thinkContent.value) {
      thinkBlockRef.value?.collapse()
    }
    
    lastRenderTime = now
    scrollToBottom()
  }

  requestAnimationFrame(processQueue)
}

// 移除原有的 watch isTesting 自动收起逻辑，改为在正文输出时即刻收起
// 或者保留作为兜底，但缩短时间
watch(isTesting, (newVal) => {
  if (!newVal && thinkContent.value && realContent.value === '') {
    setTimeout(() => {
      thinkBlockRef.value?.collapse()
    }, 200)
  }
})

// 计算替换后的完整提示词
const renderedPrompt = computed(() => {
  let preview = props.content
  detectedVariables.value.forEach(v => {
    const val = variableValues.value[v] || `{{${v}}}`
    preview = preview.replaceAll(`{{${v}}}`, val)
  })
  return preview
})

// 复制提示词
const isCopying = ref(false)
const copyPrompt = async () => {
  const success = await copyToClipboard(renderedPrompt.value)
  if (success) {
    isCopying.value = true
    setTimeout(() => {
      isCopying.value = false
    }, 2000)
  }
}

// Markdown renderer
const md = new MarkdownIt({
  html: true,
  linkify: true,
  breaks: true
})

// Use a map to store values for variables
const variableValues = ref<Record<string, string>>({})

// 复制 AI 输出内容 (排除思考内容)
const isResultCopying = ref(false)
const copyResult = async () => {
  const success = await copyToClipboard(realContent.value)
  if (success) {
    isResultCopying.value = true
    setTimeout(() => {
      isResultCopying.value = false
    }, 2000)
  }
}

// Extract unique variable names from content
const detectedVariables = computed(() => {
  const matches = props.content.match(/\{\{(.*?)\}\}/g)
  if (!matches) return []
  return Array.from(new Set(matches.map(m => m.replace(/\{\{|\}\}/g, ''))))
})

// Initialize values for new variables
watch(detectedVariables, (newVars) => {
  newVars.forEach(v => {
    if (variableValues.value[v] === undefined) {
      variableValues.value[v] = ''
    }
  })
}, { immediate: true })

const emit = defineEmits<{
  (e: 'close'): void
  (e: 'run-test', input: string): void
}>()

const scrollToBottom = async (force = false) => {
    await nextTick()
    if (drawerContentRef.value) {
        const el = drawerContentRef.value
        
        // If forced (button click) or auto-scroll is enabled
        if (force || shouldAutoScroll.value) {
            // Use smooth behavior only for manual clicks or large jumps
            if (force) {
                el.scrollTo({
                    top: el.scrollHeight,
                    behavior: 'smooth'
                })
                // Reset states after forced scroll
                shouldAutoScroll.value = true
                showScrollButton.value = false
            } else {
                el.scrollTop = el.scrollHeight
            }
        } else {
            // If auto-scroll is disabled, show button if new content is pending
            if (isTesting.value || tokenQueue.length > 0) {
                showScrollButton.value = true
            }
        }
    }
}

const handleScroll = () => {
    if (!drawerContentRef.value) return
    const el = drawerContentRef.value
    const { scrollTop, scrollHeight, clientHeight } = el
    
    // Check if user is at the bottom (threshold 50px)
    const isAtBottom = scrollHeight - scrollTop - clientHeight < 50
    
    if (isAtBottom) {
        shouldAutoScroll.value = true
        showScrollButton.value = false
    } else {
        // If user scrolls up, disable auto-scroll
        shouldAutoScroll.value = false
        
        // Show button if we are generating content or if there is new content pending
        if (isTesting.value || tokenQueue.length > 0) {
            showScrollButton.value = true
        }
    }
}

const runTest = async () => {
  if (isTesting.value) return

  const preview = renderedPrompt.value
  if (!preview.trim()) {
    toast('请先填写提示词内容', 'warning')
    return
  }

  // 使用用户输入的测试内容，如果没有输入则不发送用户消息（避免上下文污染）
  const userInput = testInput.value.trim()

  emit('run-test', preview)

  // Start real test
  isTesting.value = true

  thinkContent.value = ''
  realContent.value = ''
  let fullResponse = ''

  shouldAutoScroll.value = true // Reset auto-scroll

  // 构建请求参数，如果没有用户输入则不包含 user_input
  const requestData: any = {
    system_prompt: preview
  }
  if (userInput) {
    requestData.user_input = userInput
  }

  await testStream(
    requestData,
    (chunk) => {
      // Logic to separate think/content and push to queue
      // Note: This is a simplified stream parser. 
      // Ideally, the stream itself should distinguish types.
      // Here we parse incrementally.
      
      const prevFull = fullResponse
      fullResponse += chunk
      
      // Simple incremental parser for <think> tags
      // We compare previous state vs new state to determine what to append
      
      // Check for think tags
      const thinkStart = fullResponse.indexOf('<think>')
      const thinkEnd = fullResponse.indexOf('</think>')
      
      let newContent = ''
      let type: 'thinking' | 'answer' = 'answer'
      
      // Case 1: No think tags yet
      if (thinkStart === -1) {
        newContent = chunk
        type = 'answer'
      }
      // Case 2: Inside think block
      else if (thinkEnd === -1) {
        // Just entered think block or inside it
        if (prevFull.indexOf('<think>') === -1) {
             // Just started thinking
             const preThink = fullResponse.substring(0, thinkStart)
             const thinkPart = fullResponse.substring(thinkStart + 7)
             
             if (preThink.length > prevFull.length) {
                // Some pre-think content was added
                tokenQueue.push({ type: 'answer', text: preThink.substring(prevFull.length) })
             }
             newContent = thinkPart
             type = 'thinking'
        } else {
             // Already inside
             newContent = chunk
             type = 'thinking'
        }
      }
      // Case 3: Think block finished
      else {
        // Just finished or already finished
        if (prevFull.indexOf('</think>') === -1) {
            // Just finished
            const currentThink = fullResponse.substring(thinkStart + 7, thinkEnd)
            const currentReal = fullResponse.substring(0, thinkStart) + fullResponse.substring(thinkEnd + 8).trimStart()
            
            if (chunk.includes('</think>')) {
                 const parts = chunk.split('</think>')
                 tokenQueue.push({ type: 'thinking', text: parts[0] })
                 if (parts[1]) tokenQueue.push({ type: 'answer', text: parts[1] })
            } else {
                 // We are past think block
                 newContent = chunk
                 type = 'answer'
            }
        } else {
            // Fully past think block
            newContent = chunk
            type = 'answer'
        }
      }
      
      // Push to queue if simple append
      if (newContent) {
          tokenQueue.push({ type, text: newContent })
      }
      
      if (!isProcessingQueue) {
          processQueue()
      }
    },
    () => {
      isTesting.value = false
    },
    (err) => {
      console.error(err)
      tokenQueue.push({ type: 'answer', text: `\n[Error: ${err.message || 'Unknown error'}]` })
      if (!isProcessingQueue) processQueue()
      isTesting.value = false
      scrollToBottom()
    }
  )
}
</script>

<template>
  <div class="tools-panel">
    <!-- Header -->
    <div class="tools-header">
      <div class="header-title">配置与预览</div>
      <div class="header-actions">
        <button class="run-btn-sm" type="button" @click="runTest" :disabled="isTesting">
            <svg v-if="!isTesting" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polygon points="5 3 19 12 5 21 5 3"></polygon>
            </svg>
            <span v-if="isTesting">运行中...</span>
            <span v-else>运行</span>
        </button>
      </div>
      <button class="tools-close" @click="emit('close')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 6L6 18M6 6l12 12"/>
        </svg>
      </button>
    </div>

    <!-- Main Content (Single Scrollable Area) -->
    <div class="tools-content" ref="drawerContentRef" @scroll="handleScroll">
      <!-- 1. Config Section -->
      <div class="config-section">
          <!-- 1.1 Model & Parameters -->
          <div class="config-group">
            <div class="group-header">模型配置</div>
            <div class="control-row">
                <select v-model="model" class="ide-input model-select" disabled title="当前使用后端配置的 DeepSeek-32B 模型">
                    <option>DeepSeek-32B</option>
                </select>
                <span class="model-hint">使用后端配置模型</span>
            </div>
            <div class="control-row flex-center">
                <label class="param-label">Temp: {{ temperature }}</label>
                <input 
                    type="range" 
                    v-model.number="temperature" 
                    min="0" 
                    max="1" 
                    step="0.1" 
                    class="ide-slider"
                >
            </div>
          </div>

          <!-- 1.2 Variables -->
          <div class="config-group">
            <div 
                class="group-header clickable" 
                @click="isVariableListCollapsed = !isVariableListCollapsed"
            >
                 <span>变量表 ({{ detectedVariables.length }})</span>
                 <svg class="toggle-icon" :class="{ rotated: isVariableListCollapsed }" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="6 9 12 15 18 9"></polyline>
                 </svg>
            </div>
            
            <div class="variable-grid" v-show="!isVariableListCollapsed">
               <div class="grid-header">
                 <span class="col-name">变量名</span>
                 <span class="col-val">测试值</span>
               </div>
               <div v-if="detectedVariables.length === 0" class="empty-vars">
                 未检测到变量 (使用 <code v-pre>{{var}}</code>)
               </div>
               <div v-for="v in detectedVariables" :key="v" class="grid-row">
                  <div class="var-name" :title="'{{' + v + '}}'">{{ v }}</div>
                  <div class="var-val-wrapper">
                      <input type="text" v-model="variableValues[v]" class="ide-input compact" :placeholder="'输入 ' + v + '...'">
                  </div>
               </div>
            </div>
          </div>

          <!-- 1.3 Quick Test -->
          <div class="config-group">
            <div class="group-header">
              <span>快速测试</span>
            </div>

            <div class="preview-section">
               <div class="section-header">
                  <span class="section-title">生成的提示词 (已替换变量)</span>
                  <button class="copy-btn-xs" @click="copyPrompt" :title="isCopying ? '已复制' : '复制完整提示词'">
                     <svg v-if="!isCopying" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                     </svg>
                     <svg v-else width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="20 6 9 17 4 12"></polyline>
                     </svg>
                     {{ isCopying ? '已复制' : '复制' }}
                  </button>
               </div>
               <div class="rendered-preview">
                  {{ renderedPrompt }}
               </div>
            </div>

            <!-- 测试输入区域 -->
            <div class="test-input-section">
              <div class="section-header">
                <span class="section-title">测试输入</span>
                <span class="section-hint">额外输入，测试提示词效果（可选）</span>
              </div>
              <textarea
                v-model="testInput"
                class="test-input-textarea"
                placeholder="输入测试内容，例如：你好，请帮我分析这个问题..."
                rows="3"
              ></textarea>
            </div>
          </div>
      </div>

      <!-- Divider -->
      <div class="section-divider"></div>

      <!-- 2. Result Section -->
      <div class="result-section">
        <div v-if="realContent || thinkContent || isTesting" class="test-result">
            <div class="result-actions">
                <div class="result-label">AI 输出结果</div>
                <button class="copy-btn-xs" @click="copyResult" :title="isResultCopying ? '已复制' : '复制正文内容'">
                    <svg v-if="!isResultCopying" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
                    <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
                    </svg>
                    <svg v-else width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polyline points="20 6 9 17 4 12"></polyline>
                    </svg>
                    {{ isResultCopying ? '已复制' : '复制' }}
                </button>
            </div>

            <ThinkBlock ref="thinkBlockRef" :content="thinkContent" class="mb-4" />
            
            <div class="markdown-body output-content" v-html="md.render(realContent)"></div>

            <!-- 测试完成后的保存按钮 -->
            <div v-if="realContent && !isTesting" class="test-complete-actions">
              <div class="test-complete-hint">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#10b981" stroke-width="2">
                  <path d="M20 6L9 17l-5-5"/>
                </svg>
                <span>测试完成，效果满意？</span>
              </div>
              <button class="save-after-test-btn" @click="handleOpenSaveModal">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                  <path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2z"/>
                  <polyline points="17 21 17 13 7 13 7 21"/>
                  <polyline points="7 3 7 8 15 8"/>
                </svg>
                保存此提示词
              </button>
            </div>

            <!-- Exquisite Loading State -->
            <div v-if="isTesting && !realContent && !thinkContent" class="loading-container">
                <div class="ai-loader">
                    <div class="loader-ring"></div>
                    <div class="loader-core"></div>
                </div>
                <div class="loading-text-anim">
                    AI 正在思考中
                    <span class="dot">.</span>
                    <span class="dot">.</span>
                    <span class="dot">.</span>
                </div>
            </div>
        </div>
        <div v-else class="empty-result">
            <div class="empty-icon">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="#e5e7eb" stroke-width="1.5">
                    <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"></path>
                </svg>
            </div>
            <div class="empty-text">暂无测试结果</div>
            <button class="run-btn-simple" type="button" @click="runTest" :disabled="isTesting">
                <svg v-if="!isTesting" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <polygon points="5 3 19 12 5 21 5 3"></polygon>
                </svg>
                <span>{{ isTesting ? '正在生成结果...' : '立即运行测试' }}</span>
            </button>
        </div>
      </div>
    </div>

    <!-- Scroll to Bottom Button -->
    <Transition name="fade-slide">
      <button 
        v-if="showScrollButton" 
        class="scroll-bottom-btn"
        @click="scrollToBottom(true)"
      >
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M12 5v14M19 12l-7 7-7-7"/>
        </svg>
        <span>新内容生成中</span>
      </button>
    </Transition>

    <!-- Save Prompt Modal -->
    <SavePromptModal
      v-model:visible="showSaveModal"
      :initial-title="chatStore.currentSessionTitle"
      :messages="chatStore.messages"
      :prompt-content="content"
      :session-id="chatStore.currentSessionId"
      @save="handleSavePrompt"
      @saved="handlePromptSaved"
    />
  </div>
</template>

<style scoped>
.tools-panel {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #fff;
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  position: relative;
}

.tools-header {
  height: 48px;
  padding: 0 8px 0 16px;
  display: flex;
  align-items: center;
  /* justify-content: space-between; Removed to allow margin-auto to work properly */
  border-bottom: 1px solid #e5e7eb;
  background: #fff;
  flex-shrink: 0;
}

.header-title {
  font-size: 14px;
  font-weight: 600;
  color: #374151;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-left: auto;
  margin-right: 8px;
}

.run-btn-sm {
  display: flex;
  align-items: center;
  gap: 6px;
  background: #3b82f6;
  color: #fff;
  border: none;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.run-btn-sm:hover:not(:disabled) {
  background: #2563eb;
}

.run-btn-sm:disabled {
  background: #93c5fd;
  cursor: not-allowed;
}

.run-btn-simple {
  display: flex;
  align-items: center;
  gap: 8px;
  background: #fff;
  color: #3b82f6;
  border: 1px solid #3b82f6;
  padding: 8px 16px;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  margin-top: 16px;
}

.run-btn-simple:hover:not(:disabled) {
  background: #eff6ff;
  box-shadow: 0 2px 4px rgba(59, 130, 246, 0.1);
}

.run-btn-simple:disabled {
  border-color: #93c5fd;
  color: #93c5fd;
  cursor: not-allowed;
}

.tools-close {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
}

.tools-close:hover {
    background: #f3f4f6;
    color: #4b5563;
}

.tools-content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
}

.config-section {
    flex-shrink: 0;
}

.section-divider {
    height: 1px;
    background: #e5e7eb;
    margin: 24px 0;
}

.result-section {
    min-height: 200px; /* Ensure visibility */
}

/* Config Groups */
.config-group {
  margin-bottom: 24px;
}

.group-header {
  font-size: 12px;
  font-weight: 600;
  color: #4b5563; /* gray-600 */
  margin-bottom: 12px;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.group-header.clickable {
    cursor: pointer;
}

.group-header.clickable:hover {
    color: #111827;
}

.control-row {
    margin-bottom: 12px;
}

.flex-center {
    display: flex;
    align-items: center;
    gap: 12px;
}

/* IDE Input Styles */
.ide-input {
  width: 100%;
  background: #f9fafb; /* bg-gray-50 */
  border: 1px solid transparent; /* No border initially */
  border-radius: 6px;
  font-size: 13px;
  padding: 8px 12px;
  color: #1f2937;
  transition: all 0.2s;
}

.ide-input:focus {
  outline: none;
  background: #fff;
  border-color: #d1d5db; /* gray-300 */
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
}

.ide-input.compact {
    padding: 6px 8px;
    height: 32px;
}

.ide-input.area {
    min-height: 80px;
    resize: vertical;
}

.model-select {
    cursor: not-allowed;
    background: #f3f4f6;
    color: #6b7280;
}

.model-hint {
    font-size: 11px;
    color: #9ca3af;
    margin-left: 8px;
}

.param-label {
    font-size: 12px;
    color: #6b7280;
    min-width: 70px;
    font-family: monospace;
}

.ide-slider {
    flex: 1;
    height: 4px;
    background: #e5e7eb;
    border-radius: 2px;
    appearance: none;
}
.ide-slider::-webkit-slider-thumb {
    appearance: none;
    width: 14px;
    height: 14px;
    border-radius: 50%;
    background: #3b82f6; /* blue-500 */
    cursor: pointer;
    border: 2px solid #fff;
    box-shadow: 0 1px 2px rgba(0,0,0,0.2);
}

/* Variable Grid */
.variable-grid {
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    overflow: hidden;
}

.grid-header {
    display: flex;
    background: #f9fafb;
    padding: 8px 12px;
    border-bottom: 1px solid #e5e7eb;
    font-size: 11px;
    color: #6b7280;
    font-weight: 500;
}

.col-name { width: 40%; }
.col-val { flex: 1; }

.empty-vars {
    padding: 12px;
    text-align: center;
    color: #9ca3af;
    font-size: 12px;
    background: #fff;
}

.grid-row {
    display: flex;
    align-items: center;
    padding: 8px 12px;
    border-bottom: 1px solid #f3f4f6;
}
.grid-row:last-child { border-bottom: none; }

.var-name {
    width: 40%;
    font-size: 13px;
    color: #374151;
    font-weight: 500;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    padding-right: 8px;
}

.var-val-wrapper {
    flex: 1;
}

.toggle-icon {
    transition: transform 0.2s;
}
.toggle-icon.rotated {
    transform: rotate(-90deg);
}

/* Run Button */
.run-btn-sm {
    display: flex;
    align-items: center;
    gap: 6px;
    background: #2563eb;
    color: #fff;
    border: none;
    padding: 6px 12px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    transition: background 0.2s;
}

.run-btn-sm:hover:not(:disabled) {
    background: #1d4ed8;
}

.run-btn-sm:disabled {
    background: #93c5fd;
    cursor: not-allowed;
}

/* Preview Section */
.preview-section {
    background: #f9fafb;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    padding: 12px;
    margin-bottom: 16px;
}

.section-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
}

.section-title {
    font-size: 11px;
    font-weight: 600;
    color: #6b7280;
    text-transform: uppercase;
}

.section-hint {
    font-size: 11px;
    color: #9ca3af;
    font-weight: normal;
}

/* Test Input Section */
.test-input-section {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid #e5e7eb;
}

.test-input-textarea {
    width: 100%;
    background: #fff;
    border: 1px solid #e5e7eb;
    border-radius: 6px;
    font-size: 13px;
    padding: 10px 12px;
    color: #1f2937;
    resize: vertical;
    min-height: 80px;
    font-family: inherit;
    transition: all 0.2s;
}

.test-input-textarea:focus {
    outline: none;
    border-color: #3b82f6;
    box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.test-input-textarea::placeholder {
    color: #9ca3af;
}

/* 测试完成后保存按钮样式 */
.test-complete-actions {
    margin-top: 24px;
    padding: 16px;
    background: linear-gradient(135deg, #f0fdf4 0%, #dcfce7 100%);
    border: 1px solid #86efac;
    border-radius: 8px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
}

.test-complete-hint {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 14px;
    color: #166534;
    font-weight: 500;
}

.save-after-test-btn {
    display: flex;
    align-items: center;
    gap: 8px;
    background: #10b981;
    color: #fff;
    border: none;
    padding: 10px 20px;
    border-radius: 6px;
    font-size: 14px;
    font-weight: 600;
    cursor: pointer;
    transition: all 0.2s;
    box-shadow: 0 2px 4px rgba(16, 185, 129, 0.2);
}

.save-after-test-btn:hover {
    background: #059669;
    transform: translateY(-1px);
    box-shadow: 0 4px 8px rgba(16, 185, 129, 0.3);
}

.save-after-test-btn:active {
    transform: translateY(0);
}

.copy-btn-xs {
    background: none;
    border: 1px solid #e5e7eb;
    border-radius: 4px;
    padding: 2px 6px;
    font-size: 10px;
    color: #6b7280;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 4px;
    background: #fff;
    transition: all 0.2s;
}

.copy-btn-xs:hover {
    border-color: #d1d5db;
    color: #374151;
}

.rendered-preview {
    font-family: monospace;
    font-size: 12px;
    color: #374151;
    white-space: pre-wrap;
    word-break: break-all;
    max-height: 400px;
    overflow-y: auto;
}

/* Result View Styles */
.test-result {
    display: flex;
    flex-direction: column;
}

.result-actions {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
}

.back-btn {
    background: none;
    border: none;
    color: #6b7280;
    font-size: 13px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 0;
}

.back-btn:hover {
    color: #374151;
}

.result-label {
    font-size: 14px;
    font-weight: 600;
    color: #374151;
}

.output-content {
    flex: 1;
    font-size: 14px;
    line-height: 1.6;
    color: #374151;
    will-change: transform; /* Hardware acceleration */
    overflow-wrap: break-word;
    word-break: break-word;
    max-width: 100%;
}

/* Exquisite Loading State */
.loading-container {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 40px 0;
    gap: 16px;
}

.ai-loader {
    position: relative;
    width: 48px;
    height: 48px;
}

.loader-ring {
    position: absolute;
    inset: 0;
    border: 3px solid #e5e7eb;
    border-top-color: #2563eb;
    border-radius: 50%;
    animation: spin 1s linear infinite;
}

.loader-core {
    position: absolute;
    inset: 12px;
    background: #2563eb;
    border-radius: 50%;
    animation: pulse-core 1.5s ease-in-out infinite;
}

@keyframes spin {
    to { transform: rotate(360deg); }
}

@keyframes pulse-core {
    0% { transform: scale(0.8); opacity: 0.8; }
    50% { transform: scale(1); opacity: 1; }
    100% { transform: scale(0.8); opacity: 0.8; }
}

.loading-text-anim {
    font-size: 14px;
    color: #6b7280;
    font-weight: 500;
}

.dot {
    display: inline-block;
    animation: dot-bounce 1.4s infinite ease-in-out both;
}

.dot:nth-child(1) { animation-delay: -0.32s; }
.dot:nth-child(2) { animation-delay: -0.16s; }

@keyframes dot-bounce {
    0%, 80%, 100% { transform: scale(0); }
    40% { transform: scale(1); }
}

/* Empty State */
.empty-result {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: 100%;
    min-height: 200px;
    color: #9ca3af;
    gap: 16px;
    padding-top: 20px;
}

.empty-text {
    font-size: 14px;
}

.mr-2 {
     margin-right: 8px;
 }

 :deep(.markdown-body) {
    font-size: 14px;
    background-color: transparent;
}
:deep(.markdown-body pre) {
    background-color: #f6f8fa;
    border-radius: 6px;
    overflow-x: auto;
    max-width: 100%;
}

.scroll-bottom-btn {
  position: absolute;
  bottom: 24px;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: #fff;
  border: 1px solid #e5e7eb;
  border-radius: 20px;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  color: #2563eb;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  z-index: 10;
  transition: all 0.2s;
}

.scroll-bottom-btn:hover {
  background: #f9fafb;
  transform: translateX(-50%) translateY(-2px);
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.fade-slide-enter-active,
.fade-slide-leave-active {
  transition: all 0.3s ease;
}

.fade-slide-enter-from,
.fade-slide-leave-to {
  opacity: 0;
  transform: translateX(-50%) translateY(10px);
}
</style>

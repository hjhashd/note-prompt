<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick } from 'vue'
import { optimizeStream } from '@/api/lyf-ai'
import { Undo2, Redo2, Trash2, X } from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'
import ThinkBlock from './ThinkBlock.vue'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  content: string
}>()

const emit = defineEmits<{
  (e: 'update:content', val: string): void
  (e: 'open-config'): void
}>()

const { toast } = useToast()

// History Management
const history = ref<string[]>([])
const currentHistoryIndex = ref(-1)
const isUndoing = ref(false)
let debounceTimer: any = null

const recordChange = (val: string) => {
  clearTimeout(debounceTimer)
  debounceTimer = setTimeout(() => {
    // If we are not at the end of history, remove future states
    if (currentHistoryIndex.value < history.value.length - 1) {
      history.value = history.value.slice(0, currentHistoryIndex.value + 1)
    }
    
    // Only push if different from current head
    if (history.value[currentHistoryIndex.value] !== val) {
      history.value.push(val)
      currentHistoryIndex.value++
      
      // Limit history size
      if (history.value.length > 50) {
        history.value.shift()
        currentHistoryIndex.value--
      }
    }
  }, 500)
}

watch(() => props.content, (newVal) => {
  if (isUndoing.value) {
    isUndoing.value = false
    return
  }
  recordChange(newVal)
})

// Initialize history
onMounted(() => {
  if (props.content) {
    history.value.push(props.content)
    currentHistoryIndex.value = 0
  } else {
    // Ensure initial state is recorded
    history.value.push('')
    currentHistoryIndex.value = 0
  }
})

const undo = () => {
  if (currentHistoryIndex.value > 0) {
    currentHistoryIndex.value--
    const val = history.value[currentHistoryIndex.value]
    isUndoing.value = true
    emit('update:content', val)
  }
}

const redo = () => {
  if (currentHistoryIndex.value < history.value.length - 1) {
    currentHistoryIndex.value++
    const val = history.value[currentHistoryIndex.value]
    isUndoing.value = true
    emit('update:content', val)
  }
}

const clearContent = () => {
  if (props.content) {
    emit('update:content', '')
    toast('内容已清空', 'info')
  }
}

const isOptimizing = ref(false)
const showOptimizeConfig = ref(false)
const optimizeScene = ref('通用')
const thinkContent = ref('')

const handleOptimizeClick = () => {
  if (isOptimizing.value) return
  
  if (!props.content || !props.content.trim()) {
    toast('请先输入提示词内容', 'warning')
    return
  }
  showOptimizeConfig.value = true
}

const confirmOptimize = async () => {
  // Close modal immediately and wait for DOM update
  showOptimizeConfig.value = false
  await nextTick()

  const scene = optimizeScene.value
  
  const originalContent = props.content
  isOptimizing.value = true
  
  // Reset states
  let fullResponse = ''
  thinkContent.value = ''
  
  // Clear content to show streaming generation
  emit('update:content', '正在优化中...')

  try {
    await optimizeStream(
      {
        raw_prompt: originalContent,
        target_scene: scene
      },
      (chunk) => {
        // If it's the first chunk, clear the "Optimizing..." placeholder
        if (fullResponse === '') {
          emit('update:content', '')
        }
        
        fullResponse += chunk
        
        // Parse think content
        const thinkStart = fullResponse.indexOf('<think>')
        const thinkEnd = fullResponse.indexOf('</think>')
        
        if (thinkStart !== -1) {
          const preThink = fullResponse.substring(0, thinkStart)
          if (thinkEnd !== -1) {
            // Think block is complete
            thinkContent.value = fullResponse.substring(thinkStart + 7, thinkEnd)
            const realContent = preThink + fullResponse.substring(thinkEnd + 8).trimStart()
            emit('update:content', realContent)
          } else {
            // Think block is open
            thinkContent.value = fullResponse.substring(thinkStart + 7)
            emit('update:content', preThink) // Keep pre-think content
          }
        } else {
          // No think block found (yet), treat as normal content
          emit('update:content', fullResponse)
        }
      },
      () => {
        isOptimizing.value = false
        toast('优化完成', 'success')
      },
      (err) => {
        console.error(err)
        toast('优化失败，已恢复原始内容', 'error')
        emit('update:content', originalContent)
        isOptimizing.value = false
      }
    )
  } catch (e) {
    console.error(e)
    isOptimizing.value = false
    emit('update:content', originalContent)
  }
}

const variables = computed(() => {
  const matches = props.content.match(/\{\{(.*?)\}\}/g)
  if (!matches) return []
  return Array.from(new Set(matches.map(m => m.replace(/\{\{|\}\}/g, ''))))
})

const textareaRef = ref<HTMLTextAreaElement | null>(null)

const insertText = (text: string, selectContent = false, range?: { start: number, end: number }) => {
  if (!textareaRef.value) return
  
  const start = range ? range.start : textareaRef.value.selectionStart
  const end = range ? range.end : textareaRef.value.selectionEnd
  const content = props.content
  
  emit('update:content', content.substring(0, start) + text + content.substring(end))
  
  // Reset cursor position after next tick
  setTimeout(() => {
    if (textareaRef.value) {
      textareaRef.value.focus()
      if (selectContent) {
        // Select the content inside {{}}
        const innerContent = text.slice(2, -2)
        textareaRef.value.setSelectionRange(start + 2, start + 2 + innerContent.length)
      } else {
        textareaRef.value.setSelectionRange(start + text.length, start + text.length)
      }
    }
  }, 0)
}

const addVariable = () => {
  let name = 'variable'
  let counter = 1
  while (variables.value.includes(name)) {
    name = `variable_${counter}`
    counter++
  }

  let textToInsert = `{{${name}}}`
  let range: { start: number, end: number } | undefined

  if (textareaRef.value) {
    const selStart = textareaRef.value.selectionStart
    const selEnd = textareaRef.value.selectionEnd
    const content = props.content
    
    // Find all variables positions
    const matches = Array.from(content.matchAll(/\{\{(.*?)\}\}/g))
    
    // Check if current selection overlaps with any variable
    const overlappingVariable = matches.find(m => {
      const start = m.index!
      const end = start + m[0].length
      // Check if selection is inside or touching the variable
      return (selStart >= start && selStart <= end) || (selEnd >= start && selEnd <= end)
    })

    if (overlappingVariable) {
      const varEnd = overlappingVariable.index! + overlappingVariable[0].length
      range = { start: varEnd, end: varEnd }
      // Add a space if there isn't one
      if (varEnd < content.length && content[varEnd] !== ' ' && content[varEnd] !== '\n') {
        textToInsert = ' ' + textToInsert
      } else if (varEnd === content.length) {
         textToInsert = ' ' + textToInsert
      }
    }
  }

  insertText(textToInsert, true, range)
}
const addConstraint = () => insertText('\n约束条件：\n1. ')
const addJsonFormat = () => insertText('\n输出格式：JSON')

</script>

<template>
  <div class="editor-card">
    <div class="editor-header">
      <div class="header-tools">
        <div class="tool-group">
          <button class="icon-btn" @click="undo" :disabled="currentHistoryIndex <= 0" title="撤销">
            <Undo2 :size="18" />
          </button>
          <button class="icon-btn" @click="redo" :disabled="currentHistoryIndex >= history.length - 1" title="重做">
            <Redo2 :size="18" />
          </button>
        </div>
        <div class="tool-divider"></div>
        <div class="tool-group">
          <button class="icon-btn" @click="clearContent" title="清空内容">
            <Trash2 :size="18" />
          </button>
          <CopyButton :text="content" />
        </div>
      </div>
    </div>

    <div class="editor-toolbar">
      <button class="pill-btn" @click="addVariable">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M4 7V4h16v3M9 20h6M12 4v16"/>
        </svg>
        添加变量
      </button>
      <button class="pill-btn" @click="addConstraint">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <circle cx="12" cy="12" r="10"></circle>
          <line x1="12" y1="8" x2="12" y2="16"></line>
          <line x1="8" y1="12" x2="16" y2="12"></line>
        </svg>
        添加约束
      </button>
      <button class="pill-btn" @click="addJsonFormat">
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
          <path d="M7 8h10M7 12h10M7 16h10"/>
        </svg>
        JSON格式
      </button>
    </div>
    
    <div class="editor-content">
      <div class="editor-inner-container">
        <ThinkBlock :content="thinkContent" :scrollable="true" />
        <textarea 
          ref="textareaRef"
          class="main-textarea" 
          :value="content"
          @input="emit('update:content', ($event.target as HTMLTextAreaElement).value)"
          placeholder="在此输入提示词模板..."
        ></textarea>
      </div>
    </div>

    <div class="editor-footer">
      <div class="footer-left">
        <span class="stat-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <circle cx="12" cy="12" r="10"></circle>
            <polyline points="12 6 12 12 16 14"></polyline>
          </svg>
          最后保存: 刚刚
        </span>
        <span class="stat-item">
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z"></path>
          </svg>
          {{ variables.length }}个变量
        </span>
      </div>
      <div class="footer-right">
        <button class="action-btn ai-btn" @click="handleOptimizeClick" :disabled="isOptimizing">
          <svg v-if="!isOptimizing" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="m21.64 3.64-1.28-1.28a1.21 1.21 0 0 0-1.72 0L2.36 18.64a1.21 1.21 0 0 0 0 1.72l1.28 1.28a1.21 1.21 0 0 0 1.72 0L21.64 5.36a1.21 1.21 0 0 0 0-1.72Z"></path>
            <path d="m14 7 3 3"></path>
          </svg>
          <!-- Loading Spinner -->
          <svg v-else class="animate-spin" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <path d="M21 12a9 9 0 1 1-6.219-8.56"></path>
          </svg>
          {{ isOptimizing ? '优化中...' : 'AI 优化' }}
        </button>
        <button class="action-btn test-btn" @click="emit('open-config')">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
            <polygon points="5 3 19 12 5 21 5 3"></polygon>
          </svg>
          运行测试
        </button>
      </div>
    </div>
  </div>

  <!-- Optimize Config Modal -->
  <Transition name="fade">
    <div v-if="showOptimizeConfig" class="modal-overlay" @click.self="showOptimizeConfig = false">
      <div class="modal-content">
        <div class="modal-header">
          <h3>AI 优化设置</h3>
          <button class="close-btn" @click="showOptimizeConfig = false">
            <X :size="20" />
          </button>
        </div>
        <div class="modal-body">
          <div class="form-group">
            <label>目标场景</label>
            <input 
              v-model="optimizeScene" 
              type="text" 
              placeholder="例如: 公文写作, 代码生成" 
              @keyup.enter="confirmOptimize"
              class="modal-input"
              autofocus
            />
            <p class="hint">指定优化的目标场景，让 AI 更精准地理解您的需求</p>
          </div>
        </div>
        <div class="modal-actions">
          <button class="cancel-btn" @click="showOptimizeConfig = false">取消</button>
          <button class="primary-btn" @click="confirmOptimize">开始优化</button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.editor-card {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: #ffffff;
  border-radius: 16px;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
  overflow: hidden;
}

.editor-header {
  height: 48px;
  padding: 0 20px;
  display: flex;
  align-items: center;
  border-bottom: 1px solid var(--bg-primary);
}

.header-tools {
  display: flex;
  gap: 12px;
  align-items: center;
}

.tool-group {
  display: flex;
  gap: 4px;
  align-items: center;
}

.tool-divider {
  width: 1px;
  height: 20px;
  background-color: var(--border-subtle);
}

.icon-btn {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  cursor: pointer;
  padding: 6px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  transition: all 0.2s;
}

.icon-btn:disabled {
  opacity: 0.4;
  cursor: not-allowed;
  pointer-events: none;
}

.icon-btn:hover:not(:disabled) {
  color: var(--text-primary);
  background: var(--bg-primary);
}

.editor-toolbar {
  padding: 12px 20px;
  display: flex;
  align-items: center;
  gap: 8px;
  background: #fff;
  border-bottom: 1px solid var(--bg-primary);
}

.pill-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 32px;
  padding: 0 12px;
  border: 1px solid var(--border-light);
  background: #ffffff;
  color: var(--text-secondary);
  border-radius: 16px;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s;
}

.pill-btn:hover {
  background: var(--bg-primary);
  border-color: var(--border-subtle);
  color: var(--text-primary);
}

.editor-content {
  flex: 1;
  padding: 24px;
  overflow-y: auto;
  display: flex;
  justify-content: flex-start;
  background: #fff;
}

.editor-inner-container {
  width: 100%;
  min-height: 100%;
  display: flex;
  flex-direction: column;
  margin: 0;
}

.main-textarea {
  width: 100%;
  flex: 1;
  border: none;
  resize: none;
  font-size: 16px;
  line-height: 1.8;
  color: var(--text-primary);
  background: transparent;
  outline: none;
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  padding: 0;
}

.editor-footer {
  height: 56px;
  padding: 0 20px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-top: 1px solid var(--bg-primary);
  background: #fff;
}

.footer-left {
  display: flex;
  gap: 20px;
  color: #9ca3af;
  font-size: 13px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
}

.footer-right {
  display: flex;
  gap: 12px;
}

.action-btn {
  display: flex;
  align-items: center;
  gap: 8px;
  height: 40px;
  padding: 0 20px;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.animate-spin {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.ai-btn {
  background: #8b5cf6;
  color: #ffffff;
}

.ai-btn:hover {
  background: #7c3aed;
}

.test-btn {
  background: #3b82f6;
  color: #ffffff;
}

.test-btn:hover {
  background: #2563eb;
}

/* Modal Styles */
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
}

.modal-content {
  background: #ffffff;
  border-radius: 16px;
  width: 100%;
  max-width: 480px;
  box-shadow: var(--shadow-lg);
  border: 1px solid var(--border-subtle);
  overflow: hidden;
  animation: modal-slide-up 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

.modal-header {
  padding: 20px;
  border-bottom: 1px solid var(--bg-primary);
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.close-btn {
  background: transparent;
  border: none;
  color: var(--text-tertiary);
  cursor: pointer;
  padding: 4px;
  border-radius: 4px;
  display: flex;
  transition: all 0.2s;
}

.close-btn:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.modal-body {
  padding: 24px;
}

.form-group {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.form-group label {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-secondary);
}

.modal-input {
  width: 100%;
  padding: 10px 12px;
  border: 1px solid var(--border-light);
  border-radius: 8px;
  font-size: 14px;
  color: var(--text-primary);
  transition: all 0.2s;
  outline: none;
}

.modal-input:focus {
  border-color: #8b5cf6;
  box-shadow: 0 0 0 2px rgba(139, 92, 246, 0.1);
}

.hint {
  font-size: 12px;
  color: var(--text-tertiary);
  margin: 0;
}

.modal-actions {
  padding: 20px;
  background: var(--bg-surface);
  border-top: 1px solid var(--bg-primary);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.cancel-btn {
  padding: 8px 16px;
  border: 1px solid var(--border-light);
  background: #ffffff;
  color: var(--text-secondary);
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.cancel-btn:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.primary-btn {
  padding: 8px 20px;
  border: none;
  background: #8b5cf6;
  color: #ffffff;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.primary-btn:hover {
  background: #7c3aed;
  box-shadow: 0 4px 12px rgba(124, 58, 237, 0.2);
}

@keyframes modal-slide-up {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.96);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.2s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>

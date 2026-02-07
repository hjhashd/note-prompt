<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { testStream } from '@/api/lyf-ai'

const props = defineProps<{
  content: string
}>()

const model = ref('GPT-4 Turbo')
const temperature = ref(0.6)

const isVariableListCollapsed = ref(false)
const testInput = ref('')
const thinkContent = ref('')
const realContent = ref('')
const isTestExpanded = ref(false)
const isTesting = ref(false)

// Use a map to store values for variables
const variableValues = ref<Record<string, string>>({})

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

const runTest = async () => {
  if (isTesting.value) return

  // Replace variables in content with user values
  let preview = props.content
  detectedVariables.value.forEach(v => {
    const val = variableValues.value[v] || `[${v}]`
    preview = preview.replaceAll(`{{${v}}}`, val)
  })
  
  emit('run-test', preview)
  
  // Start real test
  isTesting.value = true
  thinkContent.value = ''
  realContent.value = ''
  let fullResponse = ''
  
  isTestExpanded.value = true // Auto expand
  
  await testStream(
    {
      system_prompt: preview,
      user_input: testInput.value || '你好' // Default input if empty
    },
    (chunk) => {
      fullResponse += chunk
      
      // Parse think content
      const thinkStart = fullResponse.indexOf('<think>')
      if (thinkStart !== -1) {
        const thinkEnd = fullResponse.indexOf('</think>')
        if (thinkEnd !== -1) {
           thinkContent.value = fullResponse.substring(thinkStart + 7, thinkEnd)
           realContent.value = fullResponse.substring(thinkEnd + 8).trimStart()
        } else {
           thinkContent.value = fullResponse.substring(thinkStart + 7)
           // realContent.value = '' // Wait until thinking is done? Or show nothing?
        }
      } else {
         if (!fullResponse.trim().startsWith('<think>')) {
            realContent.value = fullResponse
         }
      }
    },
    () => {
      isTesting.value = false
    },
    (err) => {
      console.error(err)
      realContent.value += `\n[Error: ${err.message || 'Unknown error'}]`
      isTesting.value = false
    }
  )
}

const toggleTest = () => {
    isTestExpanded.value = !isTestExpanded.value
}
</script>

<template>
  <div class="tools-panel">
    <div class="tools-header">
      <div class="tools-title">属性面板</div>
      <button class="tools-close" @click="emit('close')">
        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
          <path d="M18 6L6 18M6 6l12 12"/>
        </svg>
      </button>
    </div>

    <div class="tools-content">
      <!-- 1. Model & Parameters (Compact) -->
      <div class="config-group">
        <div class="group-header">模型配置</div>
        <div class="control-row">
            <select v-model="model" class="ide-input model-select">
                <option>GPT-4 Turbo</option>
                <option>GPT-3.5 Turbo</option>
                <option>Claude 3 Opus</option>
                <option>Gemini Pro</option>
            </select>
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

      <!-- 2. Variables (Table/Grid) -->
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
             未检测到变量 (使用 \{{var}})
           </div>
           <div v-for="v in detectedVariables" :key="v" class="grid-row">
              <div class="var-name" :title="'{{' + v + '}}'">{{ v }}</div>
              <div class="var-val-wrapper">
                  <input type="text" v-model="variableValues[v]" class="ide-input compact" :placeholder="'输入 ' + v + '...'">
              </div>
           </div>
        </div>
      </div>
    </div>

    <!-- 3. Test Area (Bottom Drawer) -->
    <div class="test-drawer" :class="{ expanded: isTestExpanded }">
       <div class="drawer-handle" @click="toggleTest">
          <div class="handle-left">
              <svg class="drawer-icon" :class="{ rotated: isTestExpanded }" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="18 15 12 9 6 15"></polyline>
              </svg>
              <span class="drawer-title">快速测试</span>
          </div>
          <button class="run-btn-sm" @click.stop="runTest" :disabled="isTesting">
            <svg v-if="!isTesting" width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polygon points="5 3 19 12 5 21 5 3"></polygon>
            </svg>
            {{ isTesting ? '运行中...' : '运行' }}
          </button>
       </div>
       
       <div class="drawer-content" v-show="isTestExpanded">
          <textarea 
            class="ide-input area" 
            v-model="testInput" 
            placeholder="输入测试内容..."
          ></textarea>
          <div v-if="realContent || thinkContent" class="test-result">
             <div class="result-label">输出结果:</div>
             <ThinkBlock :content="thinkContent" />
             <div class="markdown-body" v-html="md.render(realContent)"></div>
          </div>
       </div>
    </div>
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
}

.tools-header {
  height: 48px;
  padding: 0 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  border-bottom: 1px solid #e5e7eb;
}

.tools-title {
  font-size: 14px;
  font-weight: 600;
  color: #374151; /* gray-700 */
}

.tools-close {
  background: none;
  border: none;
  color: #9ca3af;
  cursor: pointer;
}

.tools-content {
  flex: 1;
  overflow-y: auto;
  padding: 16px;
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
    cursor: pointer;
    /* Custom arrow could be added here */
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

/* Test Drawer */
.test-drawer {
    border-top: 1px solid #e5e7eb;
    background: #fff;
    display: flex;
    flex-direction: column;
    max-height: 400px; /* Limit max height */
    transition: all 0.3s ease;
}

.drawer-handle {
    height: 40px;
    padding: 0 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    cursor: pointer;
    background: #f9fafb;
    border-bottom: 1px solid transparent;
}
.test-drawer.expanded .drawer-handle {
    border-bottom-color: #e5e7eb;
}

.handle-left {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;
    font-weight: 600;
    color: #374151;
}

.drawer-icon {
    transition: transform 0.2s;
}
.drawer-icon.rotated {
    transform: rotate(180deg);
}

.run-btn-sm {
    padding: 4px 12px;
    background: #3b82f6;
    color: white;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 500;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 4px;
}
.run-btn-sm:hover {
    background: #2563eb;
}

.drawer-content {
    padding: 16px;
    background: #fff;
}

.test-result {
    margin-top: 12px;
    padding: 12px;
    background: #f3f4f6;
    border-radius: 6px;
    font-size: 13px;
    color: #4b5563;
    line-height: 1.5;
}

.result-label {
    font-size: 11px;
    font-weight: 600;
    color: #9ca3af;
    margin-bottom: 4px;
    text-transform: uppercase;
}
</style>

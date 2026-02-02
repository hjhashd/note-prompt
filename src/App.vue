<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useUserStore } from '@/stores/user'
import { bridge } from '@/utils/bridge'
import request from '@/utils/request'

const userStore = useUserStore()
const loading = ref(false)
const promptContent = ref('')

// 示例：从后端获取数据
const fetchData = async () => {
  try {
    // 这里的 data 已经是 response.data.data 了
    const pythonResult = await request.get('/api/python/status')
    console.log('Python Backend Status:', pythonResult)
    
    const javaResult = await request.get('/api/java/health')
    console.log('Java Backend Health:', javaResult)
  } catch (err) {
    console.error('Fetch failed:', err)
  }
}

// 3.1 身份认证
onMounted(() => {
  const urlParams = new URLSearchParams(window.location.search)
  const token = urlParams.get('token')

  if (token) {
    userStore.setToken(token)
  } else {
    if (import.meta.env.DEV) {
      userStore.setToken('mock-dev-token')
      console.log('Dev mode: Mock token set')
    } else {
      alert('无法获取身份信息，请从报告系统进入')
    }
  }
})

// 3.2 应用提示词
const handleApply = async () => {
  if (!promptContent.value) return
  
  try {
    loading.value = true
    // 1. 调用宿主能力（如果是在 iframe 中）
    await bridge.call('APPLY_PROMPT', { 
      content: promptContent.value,
      id: 'demo-id' 
    })
    
    // 2. 调用后端 API 保存（示例）
    await request.post('/api/python/save-prompt', {
      content: promptContent.value
    })
    
    alert('应用并保存成功')
  } catch (err: any) {
    alert('应用失败: ' + err.message)
  } finally {
    loading.value = false
  }
}
</script>

<template>
  <div class="min-h-screen bg-gray-50 flex flex-col items-center justify-center p-4">
    <div class="bg-white p-8 rounded-lg shadow-md w-full max-w-md">
      <h1 class="text-2xl font-bold mb-6 text-gray-800">提示词系统</h1>
      
      <div v-if="userStore.token">
        <div class="mb-4">
          <label class="block text-sm font-medium text-gray-700 mb-2">提示词内容</label>
          <textarea 
            v-model="promptContent"
            class="w-full border border-gray-300 rounded-md p-2 h-32 focus:ring-primary focus:border-primary"
            placeholder="请输入提示词..."
          ></textarea>
        </div>
        
        <button 
          @click="handleApply" 
          :disabled="loading"
          class="w-full bg-primary text-white py-2 px-4 rounded hover:bg-blue-600 disabled:opacity-50 transition-colors"
        >
          {{ loading ? '应用中...' : '应用提示词' }}
        </button>
      </div>
      
      <div v-else class="text-error text-center">
        未授权访问
      </div>
    </div>
  </div>
</template>

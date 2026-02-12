<script setup lang="ts">
import { ref, provide } from 'vue'
import { useRouter } from 'vue-router'
import { Plus, Trash2, X, AlertTriangle } from 'lucide-vue-next'
import { useAppStore } from '@/stores/app'
import { useToast } from '@/composables/useToast'
import PromptList from '@/components/layout/PromptList.vue'
import TiledCategoryFilter from '@/components/prompt/TiledCategoryFilter.vue'
import type { PromptItem } from '@/types/prompt'

const router = useRouter()
const appStore = useAppStore()
const { toast } = useToast()
const currentTagId = ref<number | null>(null)

// 批量删除模式
const isDeleteMode = ref(false)
const selectedPrompts = ref<Set<number>>(new Set())
const showDeleteConfirm = ref(false)
const deleteWithSession = ref(false)

const createPrompt = () => {
  router.push('/studio')
}

// 切换删除模式
const toggleDeleteMode = () => {
  isDeleteMode.value = !isDeleteMode.value
  if (!isDeleteMode.value) {
    selectedPrompts.value.clear()
  }
}

// 选择/取消选择提示词
const togglePromptSelection = (promptId: number) => {
  if (selectedPrompts.value.has(promptId)) {
    selectedPrompts.value.delete(promptId)
  } else {
    selectedPrompts.value.add(promptId)
  }
}

// 确认删除
const confirmDelete = () => {
  if (selectedPrompts.value.size === 0) {
    toast('请先选择要删除的提示词', 'warning')
    return
  }
  showDeleteConfirm.value = true
}

// 执行删除
const promptListRef = ref<InstanceType<typeof PromptList> | null>(null)

const executeDelete = async () => {
  if (!promptListRef.value) return
  
  await promptListRef.value.deleteSelectedPrompts(deleteWithSession.value)
  showDeleteConfirm.value = false
  deleteWithSession.value = false
  isDeleteMode.value = false
}

// 取消删除
const cancelDelete = () => {
  showDeleteConfirm.value = false
  deleteWithSession.value = false
}

// 提供给子组件
provide('isDeleteMode', isDeleteMode)
provide('selectedPrompts', selectedPrompts)
provide('togglePromptSelection', togglePromptSelection)
</script>

<template>
  <div class="view-wrapper">
    <!-- Main Content Area -->
    <div class="content-body">
      <div class="content-container">
        <!-- Page Header -->
            <div class="page-header">
              <div class="header-content">
                <h1 class="page-title">我的提示词</h1>
                <p class="page-desc">管理和组织你的个人提示词库，快速访问和复用</p>
              </div>
              <div class="header-actions">
                <!-- 删除模式按钮 -->
                <button 
                  v-if="!isDeleteMode"
                  class="btn-secondary" 
                  @click="toggleDeleteMode"
                >
                  <Trash2 :size="18" />
                  <span>批量删除</span>
                </button>
                <template v-else>
                  <span class="selected-count">已选择 {{ selectedPrompts.size }} 个</span>
                  <button class="btn-danger" @click="confirmDelete" :disabled="selectedPrompts.size === 0">
                    <Trash2 :size="18" />
                    <span>确认删除</span>
                  </button>
                  <button class="btn-secondary" @click="toggleDeleteMode">
                    <X :size="18" />
                    <span>取消</span>
                  </button>
                </template>
                <button class="btn-primary" @click="createPrompt">
                  <Plus :size="20" />
                  <span>新建提示词</span>
                </button>
              </div>
            </div>

            <!-- Tiled Category Filter -->
            <div class="mb-6">
              <TiledCategoryFilter v-model="currentTagId" type="user" />
            </div>

            <!-- Prompt List -->
            <div class="list-container">
              <PromptList 
                :is-sidebar-collapsed="appStore.isSidebarCollapsed" 
                :tag-id="currentTagId"
                ref="promptListRef"
              />
            </div>
          </div>
        </div>
      </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="cancelDelete">
      <div class="modal-content">
        <div class="modal-header">
          <AlertTriangle class="warning-icon" :size="24" />
          <h3>确认删除</h3>
        </div>
        <div class="modal-body">
          <p>确定要删除选中的 <strong>{{ selectedPrompts.size }}</strong> 个提示词吗？</p>
          <p class="text-secondary">删除后提示词将无法恢复，但数据会保留在系统中。</p>
          
          <label class="checkbox-label">
            <input type="checkbox" v-model="deleteWithSession" />
            <span>同时删除关联的会话记录</span>
          </label>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="cancelDelete">取消</button>
          <button class="btn-danger" @click="executeDelete">确认删除</button>
        </div>
      </div>
    </div>
</template>

<style scoped>
.view-wrapper {
  display: flex;
  height: 100%;
  width: 100%;
}

.content-body {
    flex: 1;
    overflow-y: auto;
    padding: var(--layout-gap);
    min-width: 0; /* Prevent flex overflow */
}

.content-container {
    max-width: 1200px;
    margin: 0 auto;
    display: flex;
    flex-direction: column;
    gap: 24px;
}

.page-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
}

.page-title {
    font-size: 24px;
    font-weight: 600;
    color: var(--text-primary);
    margin-bottom: 8px;
}

.page-desc {
    color: var(--text-secondary);
    font-size: 14px;
}

.header-actions {
    display: flex;
    gap: 12px;
}

.btn-primary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: var(--primary);
    color: white;
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: none;
}

.btn-primary:hover {
    background: var(--primary-hover);
}

.btn-secondary {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: var(--bg-secondary);
    color: var(--text-primary);
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: 1px solid var(--border-subtle);
}

.btn-secondary:hover {
    background: var(--bg-tertiary);
}

.btn-danger {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 16px;
    background: #ef4444;
    color: white;
    border-radius: 8px;
    font-weight: 500;
    transition: all 0.2s;
    cursor: pointer;
    border: none;
}

.btn-danger:hover:not(:disabled) {
    background: #dc2626;
}

.btn-danger:disabled {
    opacity: 0.5;
    cursor: not-allowed;
}

.selected-count {
    font-size: 14px;
    color: var(--text-secondary);
    padding: 0 8px;
}

.list-container {
    flex: 1;
    min-height: 0;
}

/* Modal Styles */
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
}

.modal-content {
    background: var(--bg-surface);
    border-radius: 12px;
    padding: 24px;
    min-width: 400px;
    max-width: 90vw;
    box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1);
}

.modal-header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 16px;
}

.modal-header h3 {
    font-size: 18px;
    font-weight: 600;
    color: var(--text-primary);
}

.warning-icon {
    color: #f59e0b;
}

.modal-body {
    margin-bottom: 24px;
}

.modal-body p {
    margin-bottom: 8px;
    color: var(--text-primary);
}

.modal-body .text-secondary {
    color: var(--text-secondary);
    font-size: 14px;
}

.checkbox-label {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-top: 16px;
    cursor: pointer;
    font-size: 14px;
    color: var(--text-secondary);
}

.checkbox-label input[type="checkbox"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
}

.modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 12px;
}

@media (max-width: 768px) {
    .main-content {
        margin-left: var(--sidebar-width-collapsed);
    }
    
    .view-wrapper {
        flex-direction: column;
    }
    
    .header-actions {
        flex-wrap: wrap;
        gap: 8px;
    }
    
    .modal-content {
        min-width: auto;
        margin: 16px;
    }
}
</style>

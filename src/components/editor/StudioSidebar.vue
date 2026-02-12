<script setup lang="ts">
import { useChatStore } from '@/stores/chat'
import { storeToRefs } from 'pinia'
import { Plus, MessageSquare, Trash2, Pencil, ChevronRight, FolderOpen, Tag, Bookmark, Layers, Sparkles } from 'lucide-vue-next'
import { ref, onMounted, watch } from 'vue'
import { getUserTagsTree } from '@/api/prompt'
import { getPrompts } from '@/api/prompt'
import type { TagItem, PromptItem } from '@/types/prompt'
import type { ChatSessionItem } from '@/api/lyf-ai'
import DeleteConfirmModal from '@/components/common/DeleteConfirmModal.vue'
import RenameModal from '@/components/common/RenameModal.vue'

const chatStore = useChatStore()
const { sessions, currentSessionId } = storeToRefs(chatStore)
const isTagsCollapsed = ref(false)
const userTags = ref<TagItem[]>([])
const selectedTagId = ref<number | null>(null)
const promptResults = ref<PromptItem[]>([])
const promptsLoading = ref(false)
const viewMode = ref<'sessions' | 'prompts'>('sessions')

// Modal states
const showDeleteModal = ref(false)
const showRenameModal = ref(false)
const selectedSession = ref<ChatSessionItem | null>(null)
const actionLoading = ref(false)

const emit = defineEmits<{
  (e: 'switch-session', id: number): void
  (e: 'new-chat'): void
  (e: 'select-prompt', prompt: PromptItem): void
}>()

onMounted(async () => {
  try {
    userTags.value = await getUserTagsTree()
    await chatStore.loadSessions()
  } catch (error) {
    console.error('Failed to load user tags:', error)
  }
})

const handleNewChat = () => {
  selectedTagId.value = null
  viewMode.value = 'sessions'
  chatStore.createNewSession()
  emit('new-chat')
}

const handleSwitchSession = (id: number) => {
  selectedTagId.value = null
  viewMode.value = 'sessions'
  chatStore.switchToSession(id)
  emit('switch-session', id)
}

const handleDeleteSession = (e: Event, session: ChatSessionItem) => {
  e.stopPropagation()
  selectedSession.value = session
  showDeleteModal.value = true
}

const confirmDeleteSession = async (deletePrompt: boolean) => {
  if (!selectedSession.value) return
  
  actionLoading.value = true
  try {
    const result = await chatStore.removeSession(selectedSession.value.session_id, deletePrompt)
    if (result?.deleted_prompt) {
      console.log(`已同步删除关联的提示词 #${result.prompt_id}`)
    }
    showDeleteModal.value = false
  } catch (error) {
    console.error('Failed to delete session:', error)
  } finally {
    actionLoading.value = false
    selectedSession.value = null
  }
}

const handleRenameSession = (e: Event, id: number, title: string) => {
  e.stopPropagation()
  selectedSession.value = sessions.value.find(s => s.session_id === id) || null
  showRenameModal.value = true
}

const confirmRenameSession = async (newTitle: string) => {
  if (!selectedSession.value) return
  
  actionLoading.value = true
  try {
    await chatStore.renameSession(selectedSession.value.session_id, newTitle)
    showRenameModal.value = false
  } catch (error) {
    console.error('Failed to rename session:', error)
  } finally {
    actionLoading.value = false
    selectedSession.value = null
  }
}

const handleSelectTag = async (tagId: number | null) => {
  selectedTagId.value = tagId
  
  if (tagId === null) {
    viewMode.value = 'sessions'
    promptResults.value = []
    return
  }
  
  viewMode.value = 'prompts'
  promptsLoading.value = true
  
  try {
    const res = await getPrompts({
      page: 1,
      pageSize: 50,
      filter: 'my',
      sort: 'updatedAt',
      order: 'desc',
      tagId: tagId
    })
    promptResults.value = res.list || []
  } catch (error) {
    console.error('Failed to load prompts by tag:', error)
    promptResults.value = []
  } finally {
    promptsLoading.value = false
  }
}

const handleSelectPrompt = (prompt: PromptItem) => {
  emit('select-prompt', prompt)
}

const handleBackToSessions = () => {
  selectedTagId.value = null
  viewMode.value = 'sessions'
  promptResults.value = []
}
</script>

<template>
  <aside class="sidebar">
    <div class="sidebar-header">
      <button class="new-chat-btn" @click="handleNewChat">
        <Plus :size="16" />
        <span>新建对话</span>
      </button>
    </div>

    <div class="sidebar-content">
      <div class="sidebar-section">
        <div class="sidebar-section-title">
          <template v-if="viewMode === 'prompts'">
            <button class="back-btn" @click="handleBackToSessions">
              <ChevronRight :size="14" class="back-icon" />
              <span>返回对话</span>
            </button>
          </template>
          <template v-else>
            <span>对话记录</span>
          </template>
        </div>
        
        <template v-if="viewMode === 'sessions'">
          <div class="prompt-list">
            <div
              v-for="session in sessions"
              :key="session.session_id"
              class="prompt-card"
              :class="{ 
                active: session.session_id === currentSessionId, 
                saved: session.status === 1 || session.status === 'completed' 
              }"
              @click="handleSwitchSession(session.session_id)"
            >
              <div class="prompt-card-header">
                <div class="prompt-card-title">
                  <MessageSquare :size="16" class="prompt-card-icon" />
                  <span class="text-truncate">{{ session.title || '新对话' }}</span>
                </div>
                <div class="card-actions">
                  <button class="icon-btn" @click="handleRenameSession($event, session.session_id, session.title)">
                    <Pencil :size="12" />
                  </button>
                  <button class="icon-btn danger" @click="handleDeleteSession($event, session)">
                    <Trash2 :size="12" />
                  </button>
                </div>
              </div>
              <div v-if="session.status === 1 || session.status === 'completed'" class="saved-indicator">
                <Sparkles :size="10" class="sparkle-icon" />
                <span>已存为提示词</span>
              </div>
            </div>
            <div v-if="sessions.length === 0" class="empty-state">
              暂无历史记录
            </div>
          </div>
        </template>
        
        <template v-else>
          <div class="prompt-list">
            <div v-if="promptsLoading" class="loading-state">
              加载中...
            </div>
            <div v-else-if="promptResults.length === 0" class="empty-state">
              该标签下暂无提示词
            </div>
            <div
              v-else
              v-for="prompt in promptResults"
              :key="prompt.id"
              class="prompt-card prompt-item"
              @click="handleSelectPrompt(prompt)"
            >
              <div class="prompt-card-header">
                <div class="prompt-card-title">
                  <Sparkles :size="16" class="prompt-card-icon" />
                  <span class="text-truncate">{{ prompt.title }}</span>
                </div>
              </div>
              <div v-if="prompt.description" class="prompt-desc">
                {{ prompt.description.slice(0, 60) }}{{ prompt.description.length > 60 ? '...' : '' }}
              </div>
            </div>
          </div>
        </template>
      </div>

      <div class="sidebar-section">
        <div 
          class="sidebar-section-title collapsible" 
          @click="isTagsCollapsed = !isTagsCollapsed"
        >
          <span>标签目录</span>
          <ChevronRight 
            :size="14" 
            class="collapse-icon"
            :class="{ rotated: !isTagsCollapsed }"
          />
        </div>
        <div class="template-tree" v-show="!isTagsCollapsed">
          <div 
            class="tree-item"
            :class="{ active: selectedTagId === null && viewMode === 'sessions' }"
            @click="handleSelectTag(null)"
          >
            <div class="tree-item-header">
              <Layers :size="16" class="tree-icon all-icon" />
              <span class="tree-item-name">全部</span>
            </div>
          </div>
          
          <div v-if="userTags.length === 0" class="empty-state" style="padding: 0 12px;">
            暂无标签
          </div>
          <div 
            v-for="tag in userTags" 
            :key="tag.id" 
            class="tree-item"
            :class="{ active: selectedTagId === tag.id }"
            @click="handleSelectTag(tag.id)"
          >
            <div class="tree-item-header">
              <FolderOpen :size="16" class="tree-icon" v-if="tag.children && tag.children.length > 0" />
              <Tag :size="16" class="tree-icon" v-else />
              <span class="tree-item-name">{{ tag.name }}</span>
            </div>
            <div class="tree-children" v-if="tag.children && tag.children.length > 0">
              <div 
                v-for="child in tag.children" 
                :key="child.id" 
                class="tree-item child-item"
                :class="{ active: selectedTagId === child.id }"
                @click.stop="handleSelectTag(child.id)"
              >
                <div class="tree-item-header">
                  <Tag :size="14" class="tree-icon" />
                  <span class="tree-item-name">{{ child.name }}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Modals -->
    <DeleteConfirmModal
      :visible="showDeleteModal"
      :loading="actionLoading"
      title="删除对话"
      :message="`确定要删除『${selectedSession?.title || '未命名对话'}』吗？`"
      :show-checkbox="selectedSession?.status === 1 || selectedSession?.status === 'completed'"
      checkbox-label="同时从我的提示词中删除"
      @close="showDeleteModal = false"
      @confirm="confirmDeleteSession"
    />

    <RenameModal
      :visible="showRenameModal"
      :loading="actionLoading"
      title="重命名对话"
      :initial-value="selectedSession?.title || ''"
      placeholder="输入新的对话名称"
      @close="showRenameModal = false"
      @confirm="confirmRenameSession"
    />
  </aside>
</template>

<style scoped>
.sidebar {
  width: 100%;
  flex-shrink: 0;
  background: transparent;
  display: flex;
  flex-direction: column;
  position: relative;
  height: 100%;
}

.sidebar-header {
  padding: 16px;
}

.new-chat-btn {
  width: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 10px;
  background: var(--primary);
  color: white;
  border: none;
  border-radius: 8px;
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.new-chat-btn:hover {
  background: var(--primary-600);
  box-shadow: var(--shadow-sm);
}

.sidebar-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
  padding: 0 12px 12px;
}

.sidebar-section {
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.sidebar-section:first-child {
  flex: 1;
  margin-bottom: 16px;
}

.sidebar-section:last-child {
  margin-top: auto;
  padding-top: 12px;
  border-top: 1px solid var(--border-subtle);
}

.sidebar-section-title {
  font-size: 12px;
  font-weight: 600;
  color: var(--gray-500);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 8px;
  padding: 0 8px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-shrink: 0;
}

.sidebar-section-title.collapsible {
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: background 0.2s;
}

.sidebar-section-title.collapsible:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.back-btn {
  display: flex;
  align-items: center;
  gap: 4px;
  background: none;
  border: none;
  color: var(--gray-500);
  font-size: 12px;
  font-weight: 600;
  cursor: pointer;
  padding: 0;
  text-transform: uppercase;
}

.back-btn:hover {
  color: var(--primary);
}

.back-icon {
  transform: rotate(180deg);
}

.collapse-icon {
  transition: transform 0.2s;
}

.collapse-icon.rotated {
  transform: rotate(90deg);
}

.prompt-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  overflow-y: auto;
  padding: 4px;
  margin: -4px;
}

.prompt-card {
  padding: 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all 0.2s;
  box-shadow: var(--shadow-sm);
  position: relative;
  overflow: hidden;
}

.prompt-card:hover {
  border-color: var(--primary-600);
  background: var(--bg-surface-hover);
  transform: translateY(-1px);
  box-shadow: var(--shadow-md);
}

.prompt-card.active {
  background: var(--primary-light);
  border-color: var(--primary-600);
}

.prompt-card.saved {
  background: linear-gradient(135deg, var(--bg-surface) 0%, var(--primary-50) 100%);
  border-color: var(--primary-200);
}

.prompt-card.saved:hover {
  border-color: var(--primary-400);
  background: linear-gradient(135deg, var(--bg-surface-hover) 0%, var(--primary-100) 100%);
}

.saved-indicator {
  display: flex;
  align-items: center;
  gap: 4px;
  font-size: 10px;
  color: var(--primary-600);
  font-weight: 500;
  margin-top: 6px;
  padding-top: 6px;
  border-top: 1px dashed var(--primary-100);
}

.sparkle-icon {
  color: var(--primary-500);
}

.prompt-item {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.prompt-desc {
  font-size: 12px;
  color: var(--text-secondary);
  line-height: 1.4;
}

.tree-children {
  padding-left: 12px;
  border-left: 1px solid var(--border-subtle);
  margin-left: 8px;
  margin-top: 4px;
}

.child-item .tree-item-header {
  padding: 6px 8px;
  font-size: 13px;
}

.prompt-card-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.prompt-card-title {
  font-weight: 500;
  font-size: 14px;
  color: var(--gray-900);
  display: flex;
  align-items: center;
  gap: 8px;
  flex: 1;
  min-width: 0;
}

.text-truncate {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.prompt-card-icon {
  color: var(--gray-500);
  flex-shrink: 0;
}

.card-actions {
  display: flex;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.2s;
}

.prompt-card:hover .card-actions {
  opacity: 1;
}

.icon-btn {
  padding: 4px;
  border: none;
  background: transparent;
  color: var(--gray-500);
  cursor: pointer;
  border-radius: 4px;
}

.icon-btn:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.icon-btn.danger:hover {
  background: #fee2e2;
  color: #ef4444;
}

.empty-state {
  padding: 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
  background: var(--bg-surface);
  border-radius: 8px;
  border: 1px dashed var(--border-subtle);
}

.loading-state {
  padding: 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 13px;
}

.template-tree {
  max-height: 300px;
  overflow-y: auto;
  padding-right: 4px;
}

.tree-item {
  padding: 8px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  color: var(--gray-600);
  transition: all 0.2s;
}

.tree-item:hover {
  background: var(--bg-primary);
  color: var(--gray-900);
}

.tree-item.active {
  background: var(--primary-light);
  color: var(--primary-700);
}

.tree-item-header {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
}

.tree-icon {
  flex-shrink: 0;
}

.all-icon {
  color: var(--primary);
}
</style>

<script setup lang="ts">
import { useChatStore } from '@/stores/chat'
import { storeToRefs } from 'pinia'
import { Plus, MessageSquare, Trash2, Pencil, ChevronRight, ChevronLeft, MoreHorizontal, FolderOpen, Tag, Layers, Sparkles, BookmarkCheck, Clock, Link } from 'lucide-vue-next'
import { ref, onMounted, computed } from 'vue'
import { getUserTagsTree } from '@/api/prompt'
import { getPrompts } from '@/api/prompt'
import type { TagItem, PromptItem } from '@/types/prompt'
import type { ChatSessionItem } from '@/api/lyf-ai'
import DeleteConfirmModal from '@/components/common/DeleteConfirmModal.vue'
import RenameModal from '@/components/common/RenameModal.vue'

const chatStore = useChatStore()
const { sessions, currentSessionId, tempSession } = storeToRefs(chatStore)
const isTagsCollapsed = ref(true)
const isSavedCollapsed = ref(false)
const isHistoryCollapsed = ref(false)
const userTags = ref<TagItem[]>([])
const selectedTagId = ref<number | null>(null)
const promptResults = ref<PromptItem[]>([])
const promptsLoading = ref(false)

// 分离已保存提示词的会话和普通会话
const savedPromptSessions = computed(() => 
  sessions.value.filter(s => s.origin_prompt_id)
)
const normalSessions = computed(() => 
  sessions.value.filter(s => !s.origin_prompt_id)
)

// Modal states
const showDeleteModal = ref(false)
const showRenameModal = ref(false)
const selectedSession = ref<ChatSessionItem | null>(null)
const actionLoading = ref(false)

const props = defineProps<{
  canGoBack?: boolean
  canGoForward?: boolean
}>()

const emit = defineEmits<{
  (e: 'switch-session', id: number): void
  (e: 'new-chat'): void
  (e: 'select-prompt', prompt: PromptItem): void
  (e: 'preview-back'): void
  (e: 'preview-forward'): void
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
  promptResults.value = []
  chatStore.clearTempSession()
  chatStore.createNewSession()
  emit('new-chat')
}

const handleSwitchSession = async (id: number) => {
  selectedTagId.value = null
  promptResults.value = []
  chatStore.clearTempSession()
  await chatStore.switchToSession(id)
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
    promptResults.value = []
    return
  }
  
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

// Tooltip logic
const tooltip = ref({
  visible: false,
  text: '',
  x: 0,
  y: 0
})

const showTooltip = (e: MouseEvent, text: string) => {
  if (!text) return
  const target = e.currentTarget as HTMLElement
  const rect = target.getBoundingClientRect()
  
  tooltip.value = {
    visible: true,
    text,
    x: rect.left + 20,
    y: rect.bottom + 5
  }
}

const hideTooltip = () => {
  tooltip.value.visible = false
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
        <!-- 标签过滤结果区域 -->
        <template v-if="selectedTagId !== null">
          <div class="sidebar-section-title tag-filter-title">
            <span class="filter-label">
              <Tag :size="14" class="filter-icon" />
              标签筛选结果
            </span>
            <button class="clear-filter-btn" @click="handleSelectTag(null)">
              清除筛选
            </button>
          </div>
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
                <div 
                  class="prompt-card-title"
                  @mouseenter="showTooltip($event, prompt.title)"
                  @mouseleave="hideTooltip"
                >
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
        
        <!-- 正常对话列表区域 -->
        <template v-else>
          <!-- 临时会话区域 -->
          <div v-if="tempSession && !currentSessionId" class="temp-session-section">
            <div class="section-subtitle">
              <div class="subtitle-content">
                <Clock :size="13" class="subtitle-icon" />
                <span>临时会话</span>
              </div>
              <div class="nav-controls">
                <button 
                  class="nav-btn" 
                  :class="{ disabled: !canGoBack }" 
                  :disabled="!canGoBack" 
                  @click.stop="emit('preview-back')" 
                  title="返回上一个"
                >
                  <ChevronLeft :size="12" />
                </button>
                <button 
                  class="nav-btn" 
                  :class="{ disabled: !canGoForward }" 
                  :disabled="!canGoForward" 
                  @click.stop="emit('preview-forward')" 
                  title="前进"
                >
                  <ChevronRight :size="12" />
                </button>
              </div>
            </div>
            <div class="prompt-list">
              <div
                class="prompt-card temp-session-card"
                :class="{ 'is-own': tempSession.isOwnPrompt, 'is-ref': !tempSession.isOwnPrompt }"
              >
                <div class="prompt-card-header">
                  <div 
                    class="prompt-card-title"
                    @mouseenter="showTooltip($event, tempSession.title)"
                    @mouseleave="hideTooltip"
                  >
                    <component 
                      :is="tempSession.isOwnPrompt ? Sparkles : Link" 
                      :size="15" 
                      class="prompt-card-icon"
                      :class="{ 'ref-icon': !tempSession.isOwnPrompt }"
                    />
                    <span class="text-truncate">{{ tempSession.title }}</span>
                  </div>
                  <div v-if="!tempSession.isOwnPrompt" class="temp-tag">引用</div>
                </div>
              </div>
            </div>
          </div>
          
          <!-- 已保存的提示词区域 -->
          <div v-if="savedPromptSessions.length > 0" class="saved-prompts-section">
            <div 
              class="section-subtitle collapsible"
              @click="isSavedCollapsed = !isSavedCollapsed"
            >
              <div class="subtitle-content">
                <BookmarkCheck :size="13" class="subtitle-icon" />
                <span>已保存的提示词记录</span>
              </div>
              <ChevronRight 
                :size="13" 
                class="collapse-icon"
                :class="{ rotated: !isSavedCollapsed }"
              />
            </div>
            <div class="prompt-list saved-list" v-show="!isSavedCollapsed">
              <div
                v-for="session in savedPromptSessions"
                :key="session.session_id"
                class="prompt-card is-saved-prompt"
                :class="{ active: session.session_id === currentSessionId }"
                @click="handleSwitchSession(session.session_id)"
              >
                <div class="prompt-card-header">
                  <div 
                    class="prompt-card-title"
                    @mouseenter="showTooltip($event, session.title || '新对话')"
                    @mouseleave="hideTooltip"
                  >
                    <Sparkles :size="15" class="prompt-card-icon saved-icon" />
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
              </div>
            </div>
          </div>
          
          <!-- 普通对话记录区域 -->
          <div class="normal-sessions-section">
            <div 
              class="section-subtitle collapsible"
              @click="isHistoryCollapsed = !isHistoryCollapsed"
            >
              <div class="subtitle-content">
                <MessageSquare :size="13" class="subtitle-icon" />
                <span>对话记录</span>
              </div>
              <ChevronRight 
                :size="13" 
                class="collapse-icon"
                :class="{ rotated: !isHistoryCollapsed }"
              />
            </div>
            <div class="prompt-list" v-show="!isHistoryCollapsed">
              <div
                v-for="session in normalSessions"
                :key="session.session_id"
                class="prompt-card"
                :class="{ active: session.session_id === currentSessionId }"
                @click="handleSwitchSession(session.session_id)"
              >
                <div class="prompt-card-header">
                  <div 
                    class="prompt-card-title"
                    @mouseenter="showTooltip($event, session.title || '新对话')"
                    @mouseleave="hideTooltip"
                  >
                    <MessageSquare :size="15" class="prompt-card-icon" />
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
              </div>
              <div v-if="normalSessions.length === 0 && savedPromptSessions.length === 0" class="empty-state">
                暂无历史记录
              </div>
            </div>
          </div>
        </template>
      </div>

      <div class="sidebar-section tags-section">
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
            :class="{ active: selectedTagId === null }"
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

    <Teleport to="body">
      <Transition name="tooltip">
        <div 
          v-if="tooltip.visible"
          class="sidebar-tooltip"
          :style="{ left: tooltip.x + 'px', top: tooltip.y + 'px' }"
        >
          {{ tooltip.text }}
        </div>
      </Transition>
    </Teleport>
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
  overflow-y: auto;
  min-height: 0;
  padding-right: 4px; /* Space for scrollbar */
}

.sidebar-section:last-child {
  margin-top: 0; /* Let it stack naturally, or keep it auto? */
  padding-top: 12px;
  border-top: 1px solid var(--border-subtle);
  flex-shrink: 0; /* Don't shrink tags section */
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

.tag-filter-title {
  background: var(--primary-light);
  border-radius: 6px;
  padding: 6px 10px;
  margin-bottom: 10px;
}

.filter-label {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--primary);
  font-weight: 600;
}

.filter-icon {
  color: var(--primary);
}

.clear-filter-btn {
  background: transparent;
  border: 1px solid var(--primary);
  color: var(--primary);
  font-size: 11px;
  padding: 2px 8px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.clear-filter-btn:hover {
  background: var(--primary);
  color: white;
}

.tags-section {
  flex-shrink: 0;
  max-height: 40%;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.tags-section .template-tree {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
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
  gap: 2px;
  padding: 0;
  margin: 0;
}

.prompt-card {
  padding: 8px 10px;
  background: transparent;
  border: 1px solid transparent;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s ease-in-out;
  position: relative;
  overflow: hidden;
  color: var(--text-secondary);
}

.prompt-card:hover {
  background: var(--bg-surface-hover);
  color: var(--text-primary);
}

.prompt-card.active {
  background: var(--primary-light);
  color: var(--primary-700);
  font-weight: 500;
}

/* 已保存提示词的特殊样式 */
.prompt-card.is-saved-prompt {
  background: rgba(var(--primary-rgb), 0.02);
  border: 1px solid rgba(var(--primary-rgb), 0.1);
}

.prompt-card.is-saved-prompt:hover {
  background: rgba(var(--primary-rgb), 0.05);
  border-color: rgba(var(--primary-rgb), 0.2);
}

.prompt-card.is-saved-prompt.active {
  background: var(--primary-light);
  border-color: transparent;
  color: var(--primary-700);
}

.prompt-card-icon.saved-icon {
  color: var(--primary);
}

/* 分区域样式 */
.saved-prompts-section,
.normal-sessions-section,
.temp-session-section {
  margin-bottom: 16px;
}

/* 临时会话样式 - 紧凑且清晰 */
.temp-session-section .section-subtitle {
  color: var(--orange-600);
}

.temp-session-card {
  background: linear-gradient(90deg, rgba(251, 146, 60, 0.08) 0%, transparent 100%);
  border: 1px solid rgba(251, 146, 60, 0.2);
  color: var(--orange-700);
}

.temp-session-card:hover {
  background: linear-gradient(90deg, rgba(251, 146, 60, 0.15) 0%, transparent 100%);
  border-color: rgba(251, 146, 60, 0.3);
}

.temp-session-card.is-own {
  /* 自定义提示词的临时状态样式 */
  background: linear-gradient(90deg, rgba(var(--primary-rgb), 0.08) 0%, transparent 100%);
  border-color: rgba(var(--primary-rgb), 0.2);
  color: var(--primary-700);
}

.temp-session-card .ref-icon {
  color: var(--orange-500);
}

.temp-tag {
  font-size: 10px;
  color: var(--orange-600);
  background: rgba(251, 146, 60, 0.1);
  padding: 1px 5px;
  border-radius: 4px;
  margin-left: auto;
  flex-shrink: 0;
  border: 1px solid rgba(251, 146, 60, 0.2);
}

.section-subtitle {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 6px;
  font-size: 11px;
  font-weight: 600;
  color: var(--text-tertiary);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  margin-bottom: 6px;
  padding: 4px 6px;
  border-radius: 4px;
}

.section-subtitle.collapsible {
  cursor: pointer;
  transition: background 0.2s;
}

.section-subtitle.collapsible:hover {
  background: var(--bg-primary);
}

.subtitle-content {
  display: flex;
  align-items: center;
  gap: 6px;
}

.section-subtitle .subtitle-icon {
  flex-shrink: 0;
}

.saved-prompts-section .section-subtitle {
  color: var(--primary);
}

.saved-list {
  /* max-height: 200px; REMOVED */
  /* overflow-y: auto; REMOVED */
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

.nav-controls {
  display: flex;
  align-items: center;
  gap: 2px;
}

.nav-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 18px;
  height: 18px;
  padding: 0;
  border: 1px solid transparent;
  background: transparent;
  border-radius: 4px;
  color: var(--text-tertiary);
  cursor: pointer;
  transition: all 0.15s;
}

.nav-btn:hover:not(.disabled) {
  background: var(--bg-surface-hover);
  color: var(--text-primary);
  border-color: var(--border-subtle);
}

.nav-btn.disabled {
  opacity: 0.4;
  cursor: not-allowed;
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

/* Tooltip */
.sidebar-tooltip {
  position: fixed;
  z-index: 9999;
  background: var(--bg-surface, #fff);
  color: var(--text-primary, #333);
  padding: 8px 12px;
  border-radius: 6px;
  font-size: 13px;
  line-height: 1.4;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  border: 1px solid var(--border-subtle, #eee);
  max-width: 300px;
  word-wrap: break-word;
  pointer-events: none;
  transform-origin: top left;
}

.tooltip-enter-active,
.tooltip-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.tooltip-enter-from,
.tooltip-leave-to {
  opacity: 0;
  transform: translateY(-4px) scale(0.98);
}
</style>

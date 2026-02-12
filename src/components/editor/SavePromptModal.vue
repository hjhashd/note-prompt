<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { X, Save, Globe, Lock, ChevronDown, CheckCircle2, MessageSquare, Code, ChevronRight, Search, Tag, Plus, Info } from 'lucide-vue-next'
import { getTagsTree, getUserTagsTree } from '@/api/prompt'
import { 
  getPythonDepartmentsTree, 
  getPythonTagsTree, 
  createPersonalTag,
  savePromptFromStudio,
  updateTagDepartment,
  type TagNode 
} from '@/api/promptSave'
import type { TagItem } from '@/types/prompt'
import { useToast } from '@/composables/useToast'

interface Message {
  id: number | string
  role: string
  content: string
}

const props = defineProps<{
  visible: boolean
  initialTitle?: string
  initialMessageId?: number | string | null
  messages: Message[]
  promptContent: string
  sessionId: number | null
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'save', data: any): void
  (e: 'saved', data: any): void
}>()

const { toast } = useToast()
const isSaving = ref(false)

// Form State
const form = ref({
  title: '',
  sourceType: 'prompt' as 'prompt' | 'reply',
  messageId: null as number | string | null,
  visibility: 'private' as 'private' | 'plaza',
  departmentId: null as number | null,
  finalizeSession: false,
  tagIds: [] as number[],
  description: '',
  userInputExample: '',
})

// Department Tree State
const departments = ref<TagItem[]>([])
const expandedDepts = ref<number[]>([])
const showDeptDropdown = ref(false)
const deptSearchQuery = ref('')

// Tag State
const allTags = ref<TagItem[]>([])
const showTagDropdown = ref(false)
const tagSearchQuery = ref('')
const newTagName = ref('')
const isCreatingTag = ref(false)
// 跟踪本次会话中新创建的标签ID（用于保存时更新department_id）
const newlyCreatedTagIds = ref<number[]>([])

// Filtered departments based on search query
const filteredDepartments = computed(() => {
  if (!deptSearchQuery.value.trim()) return departments.value
  
  const query = deptSearchQuery.value.toLowerCase()
  
  const filterNodes = (nodes: TagItem[]): TagItem[] => {
    return nodes.reduce((acc: TagItem[], node) => {
      const match = node.name.toLowerCase().includes(query)
      const filteredChildren = node.children ? filterNodes(node.children) : []
      
      if (match || filteredChildren.length > 0) {
        acc.push({
          ...node,
          children: filteredChildren
        })
        // Auto-expand nodes that have matching children
        if (filteredChildren.length > 0 && !expandedDepts.value.includes(node.id)) {
          expandedDepts.value.push(node.id)
        }
      }
      return acc
    }, [])
  }
  
  return filterNodes(departments.value)
})

const fetchDepartments = async () => {
  try {
    // 使用Python后端API获取部门树
    const data = await getPythonDepartmentsTree()
    
    // 转换为前端TagItem格式
    const mapToTagItem = (nodes: any[]): TagItem[] => {
      return nodes.map(node => ({
        id: node.id,
        name: node.name,
        parentId: node.parent_id,
        departmentId: node.department_id,
        children: node.children ? mapToTagItem(node.children) : [],
        sortOrder: 0
      }))
    }
    
    const deptItems = mapToTagItem(data)
    
    // Add "All Departments" option at the top
    const allDeptNode: TagItem = {
      id: 0, // Special ID for "All Departments"
      name: '全部部门',
      children: [],
      parentId: null,
      sortOrder: -1
    }
    
    departments.value = [allDeptNode, ...deptItems]
  } catch (error) {
    console.error('Failed to fetch departments:', error)
    toast('获取部门列表失败', 'error')
  }
}

const fetchTags = async () => {
  try {
    // 使用Python后端API获取标签树，只获取个人标签
    const data = await getPythonTagsTree(true)
    
    // 扁平化标签，只保留个人标签（type=2）
    const flattenTags = (nodes: TagNode[]): TagItem[] => {
      return nodes.reduce((acc: TagItem[], node) => {
        // 只添加个人标签（type=2）
        if (node.type === 2) {
          acc.push({
            id: node.id,
            name: node.tag_name,
            parentId: node.parent_id,
            children: [],
            sortOrder: 0
          })
        }
        if (node.children && node.children.length > 0) {
          acc.push(...flattenTags(node.children))
        }
        return acc
      }, [])
    }
    
    // 只显示个人标签
    allTags.value = flattenTags(data.personal_tags || [])
  } catch (error) {
    console.error('Failed to fetch tags:', error)
    toast('获取标签列表失败', 'error')
  }
}

onMounted(() => {
  fetchDepartments()
  fetchTags()
})

const filteredTags = computed(() => {
  if (!tagSearchQuery.value.trim()) return allTags.value
  const query = tagSearchQuery.value.toLowerCase()
  return allTags.value.filter(tag => tag.name.toLowerCase().includes(query))
})

const selectedTags = computed(() => {
  return allTags.value.filter(tag => form.value.tagIds.includes(tag.id as number))
})

const toggleTag = (tag: TagItem) => {
  const index = form.value.tagIds.indexOf(tag.id as number)
  if (index > -1) {
    form.value.tagIds.splice(index, 1)
  } else {
    form.value.tagIds.push(tag.id as number)
  }
}

const createNewTag = async () => {
  if (!newTagName.value.trim()) return

  isCreatingTag.value = true
  try {
    // 调用Python后端API创建个人标签
    const result = await createPersonalTag({
      tag_name: newTagName.value.trim(),
      parent_id: 0
    })

    // 创建成功后添加到本地列表并选中
    const newTag: TagItem = {
      id: result.tag_id,
      name: result.tag_name,
      parentId: 0,
      children: []
    }

    allTags.value.push(newTag)
    form.value.tagIds.push(newTag.id as number)
    // 记录新创建的标签ID，保存时会更新其department_id
    newlyCreatedTagIds.value.push(result.tag_id)
    newTagName.value = ''
    tagSearchQuery.value = ''

    toast('标签创建成功', 'success')
  } catch (error) {
    console.error('Failed to create tag:', error)
    toast('创建标签失败', 'error')
  } finally {
    isCreatingTag.value = false
  }
}

const removeTag = (tagId: number) => {
  const index = form.value.tagIds.indexOf(tagId)
  if (index > -1) {
    form.value.tagIds.splice(index, 1)
  }
}

const selectedDeptName = computed(() => {
  if (form.value.departmentId === null) return '选择部门...'
  if (form.value.departmentId === 0) return '全部部门'
  
  const findName = (nodes: TagItem[]): string | null => {
    for (const node of nodes) {
      if (node.id === form.value.departmentId) return node.name
      if (node.children) {
        const name = findName(node.children)
        if (name) return name
      }
    }
    return null
  }
  return findName(departments.value) || '选择部门...'
})

const toggleDeptDropdown = (e: Event) => {
  e.stopPropagation()
  showDeptDropdown.value = !showDeptDropdown.value
}

const selectDept = (dept: TagItem) => {
  form.value.departmentId = dept.id
  showDeptDropdown.value = false
}

const toggleExpandDept = (id: number, e: Event) => {
  e.stopPropagation()
  const index = expandedDepts.value.indexOf(id)
  if (index > -1) {
    expandedDepts.value.splice(index, 1)
  } else {
    expandedDepts.value.push(id)
  }
}

// Close dropdown on click outside
const handleOutsideClick = (e: MouseEvent) => {
  const target = e.target as HTMLElement
  if (!target.closest('.custom-tree-select')) {
    showDeptDropdown.value = false
  }
  if (!target.closest('.tag-trigger-wrapper')) {
    showTagDropdown.value = false
  }
}

onMounted(() => {
  window.addEventListener('click', handleOutsideClick)
})

import { onUnmounted } from 'vue'
onUnmounted(() => {
  window.removeEventListener('click', handleOutsideClick)
})

// Initialize form
watch(() => props.visible, (newVal) => {
  if (newVal) {
    form.value.title = props.initialTitle || '新对话'

    const aiMessages = props.messages.filter(m => m.role === 'ai' || m.role === 'assistant')
    const initialMsgId = props.initialMessageId
    const hasInitial = initialMsgId !== null && initialMsgId !== undefined
    const initialMatch = hasInitial ? aiMessages.find(m => String(m.id) === String(initialMsgId)) : undefined

    if (initialMatch) {
      form.value.sourceType = 'reply'
      form.value.messageId = initialMatch.id
    } else if (aiMessages.length > 0) {
      form.value.sourceType = 'reply'
      form.value.messageId = aiMessages[aiMessages.length - 1].id
    } else {
      form.value.sourceType = 'prompt'
      form.value.messageId = null
    }

    // 重置新创建标签记录
    newlyCreatedTagIds.value = []
  }
})

const aiMessages = computed(() => 
  props.messages.filter(m => m.role === 'ai' || m.role === 'assistant')
)

const close = () => {
  emit('update:visible', false)
}

const handleSave = async () => {
  if (!form.value.title.trim()) {
    toast('请输入标题', 'warning')
    return
  }
  if (form.value.sourceType === 'reply' && !form.value.messageId) {
    toast('请选择要保存的消息', 'warning')
    return
  }
  if (form.value.visibility === 'plaza' && !form.value.departmentId) {
    toast('请选择发布部门', 'warning')
    return
  }
  if (!props.sessionId) {
    toast('会话ID无效', 'error')
    return
  }

  isSaving.value = true
  try {
    // 构建保存请求 - 确保所有字段都有值，不使用undefined
    const saveData: any = {
      session_id: props.sessionId,
      title: form.value.title.trim(),
      source_type: form.value.sourceType,
      visibility: form.value.visibility,
      tag_ids: form.value.tagIds || [],
      description: form.value.description || '',
      user_input_example: form.value.userInputExample || '',
      finalize_session: form.value.finalizeSession
    }

    // 条件字段
    if (form.value.sourceType === 'reply' && form.value.messageId) {
      saveData.message_id = Number(form.value.messageId)
    }
    if (form.value.sourceType === 'prompt' && props.promptContent) {
      saveData.content = props.promptContent
    }
    if (form.value.visibility === 'plaza' && form.value.departmentId) {
      saveData.department_id = form.value.departmentId
    }

    // 调用Python后端API保存
    const result = await savePromptFromStudio(saveData)

    // 如果保存的是公开提示词且有新创建的标签，更新标签的department_id
    if (form.value.visibility === 'plaza' &&
        form.value.departmentId &&
        newlyCreatedTagIds.value.length > 0) {
      // 找出当前选中的标签中哪些是新创建的
      const selectedNewTagIds = form.value.tagIds.filter(tagId =>
        newlyCreatedTagIds.value.includes(tagId)
      )

      if (selectedNewTagIds.length > 0) {
        console.log(`[SavePromptModal] 更新 ${selectedNewTagIds.length} 个新标签的部门ID为 ${form.value.departmentId}`)
        // 并行更新所有新创建标签的department_id
        const updatePromises = selectedNewTagIds.map(tagId =>
          updateTagDepartment(tagId, form.value.departmentId!)
            .catch(err => console.error(`[SavePromptModal] 更新标签 ${tagId} 部门失败:`, err))
        )
        await Promise.all(updatePromises)
      }
    }

    toast(form.value.promptId ? '提示词更新成功' : '提示词保存成功', 'success')

    // 触发保存成功事件
    emit('saved', {
      ...result,
      formData: form.value
    })

    // 关闭弹窗
    emit('update:visible', false)

    // 同时触发旧的save事件保持兼容性
    emit('save', {
      ...form.value,
      sessionId: props.sessionId,
      content: form.value.sourceType === 'prompt' ? props.promptContent : null,
      result
    })
  } catch (error: any) {
    console.error('Failed to save prompt:', error)
    toast(error.message || '保存失败', 'error')
  } finally {
    isSaving.value = false
  }
}

const selectMessage = (id: number | string) => {
  form.value.messageId = id
}
</script>

<template>
  <Transition name="modal-fade">
    <div v-if="visible" class="modal-overlay">
      <div class="modal-container">
        <!-- Header -->
        <div class="modal-header">
          <div class="header-left">
            <div class="icon-box">
              <Save :size="18" class="text-blue-500" />
            </div>
            <h3 class="modal-title">保存提示词</h3>
          </div>
          <button class="close-btn" @click="close">
            <X :size="20" />
          </button>
        </div>

        <!-- Content -->
        <div class="modal-content">
          <div class="save-notice">
            <Info :size="14" class="notice-icon" />
            <span>提示：仅保存选中内容为提示词，可在对话列表或库中查看。</span>
          </div>
          <div class="form-scroll-area">
            <!-- 1. Title -->
            <div class="form-item">
              <label class="form-label required">提示词标题</label>
              <input 
                v-model="form.title" 
                type="text" 
                class="form-input" 
                placeholder="给你的提示词起个名字..."
                maxlength="255"
              >
            </div>

            <!-- 2. Source Type -->
            <div class="form-item">
              <label class="form-label">保存来源</label>
              <div class="source-toggle">
                <button 
                  class="source-btn" 
                  :class="{ active: form.sourceType === 'reply' }"
                  @click="form.sourceType = 'reply'"
                  :disabled="aiMessages.length === 0"
                >
                  <MessageSquare :size="16" />
                  <span>AI 回复</span>
                </button>
                <button 
                  class="source-btn" 
                  :class="{ active: form.sourceType === 'prompt' }"
                  @click="form.sourceType = 'prompt'"
                >
                  <Code :size="16" />
                  <span>当前编辑器</span>
                </button>
              </div>
            </div>

            <!-- 3. Message Selection (if reply) -->
            <Transition name="fade-height">
              <div v-if="form.sourceType === 'reply'" class="form-item">
                <label class="form-label required">选择消息内容</label>
                <div class="message-list">
                  <div 
                    v-for="msg in aiMessages" 
                    :key="msg.id"
                    class="message-item"
                    :class="{ selected: form.messageId === msg.id }"
                    @click="selectMessage(msg.id)"
                  >
                    <div class="message-check">
                      <CheckCircle2 :size="14" v-if="form.messageId === msg.id" />
                      <div class="check-dot" v-else></div>
                    </div>
                    <div class="message-preview">{{ msg.content }}</div>
                  </div>
                </div>
              </div>
            </Transition>

            <!-- 4. Tags -->
            <div class="form-item">
              <label class="form-label">标签</label>
              <div class="tag-selection-container">
                <div class="selected-tags-area">
                  <div 
                    v-for="tag in selectedTags" 
                    :key="tag.id" 
                    class="tag-chip"
                  >
                    <span>{{ tag.name }}</span>
                    <button class="remove-tag" @click="removeTag(tag.id as number)">
                      <X :size="12" />
                    </button>
                  </div>
                  <div class="tag-trigger-wrapper">
                    <button 
                      class="add-tag-trigger" 
                      @click="showTagDropdown = !showTagDropdown"
                      :class="{ active: showTagDropdown }"
                    >
                      <Plus :size="14" />
                      <span>添加标签</span>
                    </button>
                    
                    <Transition name="dropdown-fade">
                      <div v-if="showTagDropdown" class="tag-dropdown" @click.stop>
                        <div class="tag-search">
                          <Search :size="14" />
                          <input 
                            v-model="tagSearchQuery" 
                            type="text" 
                            placeholder="搜索标签..."
                            @keyup.enter="createNewTag"
                          >
                        </div>
                        <div class="tag-list custom-scrollbar">
                          <div 
                            v-for="tag in filteredTags" 
                            :key="tag.id"
                            class="tag-item"
                            :class="{ selected: form.tagIds.includes(tag.id as number) }"
                            @click="toggleTag(tag)"
                          >
                            <Tag :size="14" />
                            <span>{{ tag.name }}</span>
                            <CheckCircle2 v-if="form.tagIds.includes(tag.id as number)" :size="14" class="ml-auto" />
                          </div>
                          <div v-if="filteredTags.length === 0 && !tagSearchQuery" class="empty-tags">
                            暂无标签
                          </div>
                          <div v-if="tagSearchQuery && !filteredTags.some(t => t.name === tagSearchQuery)" class="create-tag-option" @click="newTagName = tagSearchQuery; createNewTag()">
                            <Plus :size="14" />
                            <span>创建新标签: "{{ tagSearchQuery }}"</span>
                          </div>
                        </div>
                        <div class="tag-create-input">
                          <input 
                            v-model="newTagName" 
                            type="text" 
                            placeholder="新建个人标签..."
                            @keyup.enter="createNewTag"
                          >
                          <button 
                            class="create-btn" 
                            @click="createNewTag"
                            :disabled="!newTagName.trim() || isCreatingTag"
                          >
                            <Plus :size="16" />
                          </button>
                        </div>
                      </div>
                    </Transition>
                  </div>
                </div>
              </div>
            </div>

            <!-- 5. Visibility -->
            <div class="form-item">
              <label class="form-label">可见范围</label>
              <div class="visibility-options">
                <div 
                  class="vis-option" 
                  :class="{ active: form.visibility === 'private' }"
                  @click="form.visibility = 'private'"
                >
                  <Lock :size="16" />
                  <div class="vis-info">
                    <div class="vis-name">私有</div>
                    <div class="vis-desc">仅自己可见</div>
                  </div>
                </div>
                <div 
                  class="vis-option" 
                  :class="{ active: form.visibility === 'plaza' }"
                  @click="form.visibility = 'plaza'"
                >
                  <Globe :size="16" />
                  <div class="vis-info">
                    <div class="vis-name">公开</div>
                    <div class="vis-desc">发布到广场</div>
                  </div>
                </div>
              </div>
            </div>

            <!-- 5. Department (if plaza) -->
            <Transition name="fade-height">
              <div v-if="form.visibility === 'plaza'" class="form-item">
                <label class="form-label required">发布部门</label>
                <div class="custom-tree-select" @click.stop>
                  <div 
                    class="select-trigger" 
                    :class="{ active: showDeptDropdown, placeholder: !form.departmentId }"
                    @click="toggleDeptDropdown"
                  >
                    <span>{{ selectedDeptName }}</span>
                    <ChevronDown class="trigger-icon" :size="16" />
                  </div>
                  
                  <Transition name="dropdown-fade">
                    <div v-if="showDeptDropdown" class="tree-dropdown">
                      <div class="dropdown-search">
                        <Search :size="14" />
                        <input 
                          v-model="deptSearchQuery" 
                          type="text" 
                          placeholder="搜索部门..."
                          @click.stop
                        >
                      </div>
                      <div class="tree-content custom-scrollbar">
                        <template v-for="dept in filteredDepartments" :key="dept.id">
                          <!-- Recursive tree rendering -->
                          <div class="dept-node">
                            <div 
                              class="dept-item" 
                              :class="{ active: form.departmentId === dept.id, expanded: expandedDepts.includes(dept.id) }"
                              @click="selectDept(dept)"
                            >
                              <div 
                                class="expand-toggle" 
                                :class="{ hidden: !dept.children || dept.children.length === 0 }"
                                @click.stop="toggleExpandDept(dept.id, $event)"
                              >
                                <ChevronRight :size="14" />
                              </div>
                              <span class="dept-name">{{ dept.name }}</span>
                            </div>
                            
                            <!-- Sub-departments (Recursion level 1) -->
                            <div v-if="expandedDepts.includes(dept.id) && dept.children && dept.children.length > 0" class="sub-depts">
                              <div 
                                v-for="child in dept.children" 
                                :key="child.id" 
                                class="dept-node"
                              >
                                <div 
                                  class="dept-item child-node" 
                                  :class="{ active: form.departmentId === child.id, expanded: expandedDepts.includes(child.id) }"
                                  @click="selectDept(child)"
                                >
                                  <div 
                                    class="expand-toggle" 
                                    :class="{ hidden: !child.children || child.children.length === 0 }"
                                    @click.stop="toggleExpandDept(child.id, $event)"
                                  >
                                    <ChevronRight :size="14" />
                                  </div>
                                  <span class="dept-name">{{ child.name }}</span>
                                </div>

                                <!-- Grand-departments (Recursion level 2) -->
                                <div v-if="expandedDepts.includes(child.id) && child.children && child.children.length > 0" class="sub-depts">
                                  <div 
                                    v-for="subChild in child.children" 
                                    :key="subChild.id" 
                                    class="dept-node"
                                  >
                                    <div 
                                      class="dept-item grandchild-node"
                                      :class="{ active: form.departmentId === subChild.id, expanded: expandedDepts.includes(subChild.id) }"
                                      @click="selectDept(subChild)"
                                    >
                                      <div 
                                        class="expand-toggle" 
                                        :class="{ hidden: !subChild.children || subChild.children.length === 0 }"
                                        @click.stop="toggleExpandDept(subChild.id, $event)"
                                      >
                                        <ChevronRight :size="14" />
                                      </div>
                                      <span class="dept-name">{{ subChild.name }}</span>
                                    </div>
                                    
                                    <!-- Level 3 (Rare, but supported) -->
                                    <div v-if="expandedDepts.includes(subChild.id) && subChild.children && subChild.children.length > 0" class="sub-depts">
                                      <div 
                                        v-for="subSubChild in subChild.children" 
                                        :key="subSubChild.id" 
                                        class="dept-item level3-node"
                                        :class="{ active: form.departmentId === subSubChild.id }"
                                        @click="selectDept(subSubChild)"
                                      >
                                        <span class="dept-name">{{ subSubChild.name }}</span>
                                      </div>
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        </template>
                        <div v-if="filteredDepartments.length === 0" class="empty-tree">
                          {{ departments.length === 0 ? '加载中...' : '未找到匹配部门' }}
                        </div>
                      </div>
                    </div>
                  </Transition>
                </div>
              </div>
            </Transition>
          </div>
        </div>

        <!-- Footer -->
        <div class="modal-footer">
          <button class="footer-btn secondary" @click="close" :disabled="isSaving">取消</button>
          <button class="footer-btn primary" @click="handleSave" :disabled="isSaving">
            <span v-if="isSaving" class="loading-spinner"></span>
            <span>{{ isSaving ? '保存中...' : '确认保存' }}</span>
          </button>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(15, 23, 42, 0.4);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 2000;
}

.modal-container {
  background: var(--bg-surface);
  width: 100%;
  max-width: 500px;
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-xl);
  display: flex;
  flex-direction: column;
  border: 1px solid var(--border-light);
}

.modal-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.icon-box {
  width: 32px;
  height: 32px;
  background: var(--primary-light);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-title {
  font-size: 16px;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.close-btn {
  background: none;
  border: none;
  color: var(--text-tertiary);
  cursor: pointer;
  padding: 4px;
  border-radius: var(--radius-sm);
  transition: all 0.2s;
}

.close-btn:hover {
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.modal-content {
  padding: 20px;
  max-height: 60vh;
  overflow-y: auto;
}

.save-notice {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 12px;
  background: var(--bg-primary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  margin-bottom: 20px;
  font-size: 13px;
  color: var(--text-secondary);
}

.notice-icon {
  color: var(--primary);
  flex-shrink: 0;
}

.form-item {
  margin-bottom: 20px;
}

.form-label {
  display: block;
  font-size: 13px;
  font-weight: 500;
  color: var(--text-secondary);
  margin-bottom: 8px;
}

.form-label.required::after {
  content: '*';
  color: var(--danger);
  margin-left: 4px;
}

.form-input {
  width: 100%;
  height: 38px;
  padding: 0 12px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  font-size: 14px;
  color: var(--text-primary);
  transition: all 0.2s;
}

.form-input:focus {
  outline: none;
  border-color: var(--primary);
  background: var(--bg-surface);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.source-toggle {
  display: flex;
  background: var(--bg-primary);
  padding: 4px;
  border-radius: var(--radius-sm);
  gap: 4px;
}

.source-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  height: 32px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  border-radius: 6px;
  transition: all 0.2s;
}

.source-btn:hover:not(:disabled) {
  color: var(--text-primary);
}

.source-btn.active {
  background: var(--bg-surface);
  color: var(--primary);
  box-shadow: var(--shadow-sm);
}

.source-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.message-list {
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  max-height: 120px;
  overflow-y: auto;
  background: var(--bg-secondary);
}

.message-item {
  padding: 10px 12px;
  display: flex;
  gap: 10px;
  cursor: pointer;
  transition: all 0.2s;
  border-bottom: 1px solid var(--border-subtle);
}

.message-item:last-child {
  border-bottom: none;
}

.message-item:hover {
  background: var(--bg-primary);
}

.message-item.selected {
  background: var(--primary-light);
}

.message-check {
  flex-shrink: 0;
  width: 18px;
  height: 18px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--primary);
}

.check-dot {
  width: 14px;
  height: 14px;
  border: 1px solid var(--text-tertiary);
  border-radius: 50%;
}

/* Tag Styles */
.tag-selection-container {
  width: 100%;
}

.selected-tags-area {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  min-height: 38px;
  padding: 4px;
  border-radius: var(--radius-sm);
  align-items: center;
}

.tag-chip {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  background: var(--primary-light);
  color: var(--primary);
  border-radius: 100px;
  font-size: 12px;
  font-weight: 500;
  border: 1px solid rgba(59, 130, 246, 0.1);
}

.remove-tag {
  display: flex;
  align-items: center;
  justify-content: center;
  background: none;
  border: none;
  color: var(--primary);
  padding: 0;
  cursor: pointer;
  opacity: 0.6;
  transition: opacity 0.2s;
}

.remove-tag:hover {
  opacity: 1;
}

.tag-trigger-wrapper {
  position: relative;
}

.add-tag-trigger {
  display: flex;
  align-items: center;
  gap: 6px;
  height: 30px;
  padding: 0 12px;
  background: var(--bg-secondary);
  border: 1px dashed var(--border-light);
  border-radius: 100px;
  font-size: 12px;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.2s;
}

.add-tag-trigger:hover, .add-tag-trigger.active {
  border-color: var(--primary);
  color: var(--primary);
  background: var(--bg-surface);
}

.tag-dropdown {
  position: absolute;
  top: calc(100% + 8px);
  left: 0;
  width: 240px;
  background: var(--bg-surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  z-index: 2100;
  display: flex;
  flex-direction: column;
}

.tag-search {
  padding: 8px 12px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--text-tertiary);
}

.tag-search input {
  flex: 1;
  border: none;
  background: transparent;
  font-size: 13px;
  color: var(--text-primary);
  outline: none;
}

.tag-list {
  max-height: 200px;
  overflow-y: auto;
  padding: 4px;
}

.tag-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  font-size: 13px;
  color: var(--text-secondary);
  transition: all 0.2s;
}

.tag-item:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.tag-item.selected {
  background: var(--primary-light);
  color: var(--primary);
}

.empty-tags {
  padding: 20px;
  text-align: center;
  color: var(--text-tertiary);
  font-size: 12px;
}

.create-tag-option {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 10px;
  color: var(--primary);
  font-size: 13px;
  cursor: pointer;
  border-top: 1px solid var(--border-light);
  margin-top: 4px;
}

.tag-create-input {
  padding: 8px;
  border-top: 1px solid var(--border-light);
  display: flex;
  gap: 8px;
}

.tag-create-input input {
  flex: 1;
  height: 32px;
  padding: 0 10px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  font-size: 12px;
  outline: none;
}

.create-btn {
  width: 32px;
  height: 32px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--primary);
  color: white;
  border: none;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all 0.2s;
}

.create-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.ml-auto {
  margin-left: auto;
}

.message-preview {
  font-size: 13px;
  color: var(--text-secondary);
  line-height: 1.5;
  display: -webkit-box;
  -webkit-line-clamp: 1;
  -webkit-box-orient: vertical;
  overflow: hidden;
  word-break: break-all;
}

.visibility-options {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 12px;
}

.vis-option {
  padding: 12px;
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  display: flex;
  gap: 12px;
  cursor: pointer;
  transition: all 0.2s;
  background: var(--bg-secondary);
}

.vis-option:hover {
  border-color: var(--text-tertiary);
  background: var(--bg-primary);
}

.vis-option.active {
  border-color: var(--primary);
  background: var(--primary-light);
  color: var(--primary);
}

.vis-option svg {
  margin-top: 2px;
  color: var(--text-secondary);
}

.vis-option.active svg {
  color: var(--primary);
}

.vis-name {
  font-size: 14px;
  font-weight: 600;
  margin-bottom: 2px;
}

.vis-desc {
  font-size: 11px;
  color: var(--text-tertiary);
}

.vis-option.active .vis-desc {
  color: var(--primary);
  opacity: 0.8;
}

.select-wrapper {
  position: relative;
}

.custom-tree-select {
  position: relative;
  width: 100%;
}

.select-trigger {
  width: 100%;
  height: 38px;
  padding: 0 12px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  font-size: 14px;
  color: var(--text-primary);
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  transition: all 0.2s;
}

.select-trigger:hover {
  border-color: var(--text-tertiary);
}

.select-trigger.active {
  border-color: var(--primary);
  background: var(--bg-surface);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.1);
}

.select-trigger.placeholder {
  color: var(--text-tertiary);
}

.trigger-icon {
  color: var(--text-tertiary);
  transition: transform 0.2s;
}

.select-trigger.active .trigger-icon {
  transform: rotate(180deg);
  color: var(--primary);
}

.tree-dropdown {
  position: absolute;
  top: calc(100% + 4px);
  left: 0;
  right: 0;
  background: var(--bg-surface);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  box-shadow: var(--shadow-lg);
  z-index: 2100;
  display: flex;
  flex-direction: column;
  max-height: 300px;
}

.dropdown-search {
  padding: 8px 12px;
  border-bottom: 1px solid var(--border-light);
  display: flex;
  align-items: center;
  gap: 8px;
  color: var(--text-tertiary);
}

.dropdown-search input {
  flex: 1;
  border: none;
  background: transparent;
  font-size: 13px;
  color: var(--text-primary);
  outline: none;
}

.tree-content {
  padding: 4px;
  overflow-y: auto;
  flex: 1;
}

.dept-node {
  display: flex;
  flex-direction: column;
}

.dept-item {
  display: flex;
  align-items: center;
  padding: 8px 10px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  gap: 4px;
  transition: all 0.2s;
}

.dept-item:hover {
  background: var(--bg-primary);
}

.dept-item.active {
  background: var(--primary-light);
}

.child-node {
  padding-left: 12px;
}

.grandchild-node {
  padding-left: 24px;
}

.level3-node {
  padding-left: 36px;
}

.sub-depts {
  display: flex;
  flex-direction: column;
}

.expand-toggle {
  width: 20px;
  height: 20px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-tertiary);
  transition: all 0.2s;
  border-radius: 4px;
}

.expand-toggle:hover {
  background: var(--bg-secondary);
  color: var(--text-secondary);
}

.dept-item.expanded .expand-toggle {
  transform: rotate(90deg);
}

.expand-toggle.hidden {
  visibility: hidden;
}

.dept-name {
  font-size: 13px;
  color: var(--text-secondary);
  flex: 1;
}

.dept-item.active .dept-name {
  color: var(--primary);
  font-weight: 600;
}

.empty-tree {
  padding: 20px;
  text-align: center;
  color: var(--text-tertiary);
  font-size: 13px;
}

.checkbox-item {
  margin-top: 24px;
}

.checkbox-container {
  display: flex;
  gap: 12px;
  cursor: pointer;
  user-select: none;
}

.checkbox-container input {
  display: none;
}

.checkmark {
  flex-shrink: 0;
  width: 18px;
  height: 18px;
  background-color: var(--bg-secondary);
  border: 1px solid var(--text-tertiary);
  border-radius: 4px;
  position: relative;
  transition: all 0.2s;
  margin-top: 2px;
}

.checkbox-container:hover input ~ .checkmark {
  border-color: var(--text-secondary);
}

.checkbox-container input:checked ~ .checkmark {
  background-color: var(--primary);
  border-color: var(--primary);
}

.checkmark:after {
  content: "";
  position: absolute;
  display: none;
  left: 6px;
  top: 2px;
  width: 5px;
  height: 10px;
  border: solid white;
  border-width: 0 2px 2px 0;
  transform: rotate(45deg);
}

.checkbox-container input:checked ~ .checkmark:after {
  display: block;
}

.label-title {
  font-size: 14px;
  font-weight: 500;
  color: var(--text-primary);
}

.label-desc {
  font-size: 12px;
  color: var(--text-tertiary);
  margin-top: 2px;
}

.modal-footer {
  padding: 16px 20px;
  border-top: 1px solid var(--border-light);
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  background: var(--bg-secondary);
}

.footer-btn {
  height: 38px;
  padding: 0 20px;
  border-radius: var(--radius-sm);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.footer-btn.primary {
  background: var(--primary);
  color: white;
  border: none;
}

.footer-btn.primary:hover {
  background: var(--primary-hover);
}

.footer-btn.secondary {
  background: var(--bg-surface);
  color: var(--text-secondary);
  border: 1px solid var(--border-light);
}

.footer-btn.secondary:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
}

.footer-btn:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.footer-btn.primary:disabled {
  background: var(--primary);
}

.loading-spinner {
  display: inline-block;
  width: 14px;
  height: 14px;
  border: 2px solid rgba(255, 255, 255, 0.3);
  border-top-color: white;
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
  margin-right: 6px;
}

@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

/* Transitions */
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity 0.3s ease;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-active .modal-container {
  transition: transform 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.modal-fade-leave-active .modal-container {
  transition: transform 0.2s ease-in;
}

.modal-fade-enter-from .modal-container {
  transform: scale(0.9) translateY(20px);
}

.modal-fade-leave-to .modal-container {
  transform: scale(0.95);
}

.fade-height-enter-active,
.fade-height-leave-active {
  transition: all 0.3s ease;
  max-height: 200px;
  overflow: hidden;
}

.fade-height-enter-from,
.fade-height-leave-to {
  opacity: 0;
  max-height: 0;
  margin-bottom: 0;
}
</style>

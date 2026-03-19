<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue'
import { X, Save, Globe, Lock, ChevronDown, CheckCircle2, MessageSquare, Code, ChevronRight, Search, Tag, Plus, Info, AlertCircle, Loader2 } from 'lucide-vue-next'
import { getTagsTree, getUserTagsTree } from '@/api/prompt'
import { 
  getPythonDepartmentsTree, 
  getPythonTagsTree, 
  createPersonalTag,
  savePromptFromStudio,
  updateTagDepartment,
  type TagNode 
} from '@/api/promptSave'
import { createChatSession } from '@/api/lyf-ai'
import type { TagItem } from '@/types/prompt'
import { useToast } from '@/composables/useToast'
import { useUserStore } from '@/stores/user'

// Module-level cache to persist data across re-opens
let cachedDepartments: TagItem[] | null = null
let cachedTags: TagItem[] | null = null
let isFetchingGlobal = false

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
  promptId?: number | null
  mode?: 'dialogue' | 'editor' | 'test'  // 保存模式：dialogue-对话, editor-编辑器, test-测试
  originalPromptTitle?: string | null  // 引用的原始提示词标题（用于验证）
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'save', data: any): void
  (e: 'saved', data: any): void
}>()

const { toast } = useToast()
const userStore = useUserStore()
const isSaving = ref(false)

const userDepartmentId = computed(() => {
  return userStore.userInfo?.department_id ?? userStore.userInfo?.departmentId ?? null
})

// Form State
const form = ref({
  title: '',
  sourceType: 'prompt' as 'prompt' | 'reply',
  messageId: null as number | string | null,
  visibility: 'private' as 'private' | 'plaza',
  departmentId: null as number | null,
  finalizeSession: true,
  tagIds: [] as number[],
  description: '',
  userInputExample: '',
  promptId: null as number | null,
})

// Department Tree State
const departments = ref<TagItem[]>([])
const expandedDepts = ref<number[]>([])
const showDeptDropdown = ref(false)

// Tag State
const allTags = ref<TagItem[]>([])
const tagSearchQuery = ref('')
const isCreatingTag = ref(false)
// 跟踪本次会话中新创建的标签ID（用于保存时更新department_id）
const newlyCreatedTagIds = ref<number[]>([])
// 用户是否选择将选中的私有标签设为公开
const makeSelectedTagsPublic = ref(true)

// 计算选中的私有标签ID列表（已存在且未公开的个人标签）
const selectedPrivateTagIds = computed(() => {
  return form.value.tagIds.filter(tagId => {
    const tag = allTags.value.find(t => t.id === tagId)
    // 只包含已存在的标签（非本次新创建）且没有 departmentId 的标签
    return tag && !tag.departmentId && !newlyCreatedTagIds.value.includes(tagId)
  })
})

// Filtered departments based on search query and user permission
// 用户优先选择自己的部门，如果没有绑定部门则显示"全部部门"
const filteredDepartments = computed(() => {
  const userDeptId = userDepartmentId.value
  const ALL_DEPT_ID = 1 // "全部部门"在数据库中的ID

  // 从完整树中查找指定ID的部门节点（扁平化，不包含children）
  const findDeptById = (nodes: TagItem[], targetId: number): TagItem | null => {
    for (const node of nodes) {
      if (node.id === targetId) {
        // 返回不包含子节点的副本
        return { ...node, children: [] }
      }
      if (node.children && node.children.length > 0) {
        const found = findDeptById(node.children, targetId)
        if (found) return found
      }
    }
    return null
  }

  // 构建可选项列表：优先显示自己部门，没有则显示全部部门
  const buildOptions = (): TagItem[] => {
    const options: TagItem[] = []

    if (userDeptId !== null) {
      // 用户有绑定部门，只显示所属部门
      const userDept = findDeptById(departments.value, userDeptId)
      if (userDept) {
        options.push(userDept)
      }
    } else {
      // 用户没有绑定部门，显示"全部部门"作为兜底
      const allDept = findDeptById(departments.value, ALL_DEPT_ID)
      if (allDept) {
        options.push(allDept)
      }
    }

    return options
  }

  const options = buildOptions()

  // 如果只有一个选项，自动选中
  if (options.length === 1 && form.value.departmentId !== options[0].id) {
    form.value.departmentId = options[0].id
  }

  return options
})

// 是否只有一个部门选项
const hasSingleDeptOption = computed(() => filteredDepartments.value.length === 1)

const isFetchingData = ref(false)

const fetchDepartments = async () => {
  if (cachedDepartments) {
    departments.value = cachedDepartments
    return
  }

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
    
    // 使用数据库中已有的"全部部门"(ID=1)，不再创建虚拟节点
    cachedDepartments = deptItems
    departments.value = deptItems
  } catch (error) {
    console.error('Failed to fetch departments:', error)
    toast('获取部门列表失败', 'error')
  }
}

const fetchTags = async () => {
  if (cachedTags) {
    allTags.value = cachedTags
    return
  }

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
            departmentId: node.department_id,
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
    const tags = flattenTags(data.personal_tags || [])
    cachedTags = tags
    allTags.value = tags
  } catch (error) {
    console.error('Failed to fetch tags:', error)
    toast('获取标签列表失败', 'error')
  }
}

onMounted(async () => {
  if (isFetchingGlobal) {
    // Wait briefly if another instance is fetching (unlikely given modal nature but good for safety)
    const checkInterval = setInterval(() => {
      if (!isFetchingGlobal) {
        clearInterval(checkInterval)
        if (cachedDepartments) departments.value = cachedDepartments
        if (cachedTags) allTags.value = cachedTags
      }
    }, 100)
    return
  }

  if (!cachedDepartments || !cachedTags) {
    isFetchingData.value = true
    isFetchingGlobal = true
    try {
      await Promise.all([fetchDepartments(), fetchTags()])
    } finally {
      isFetchingData.value = false
      isFetchingGlobal = false
    }
  } else {
    departments.value = cachedDepartments
    allTags.value = cachedTags
  }
})

const filteredTags = computed(() => {
  if (!tagSearchQuery.value.trim()) return allTags.value
  const query = tagSearchQuery.value.toLowerCase()
  return allTags.value.filter(tag => tag.name.toLowerCase().includes(query))
})

const toggleTag = (tag: TagItem) => {
  const index = form.value.tagIds.indexOf(tag.id as number)
  if (index > -1) {
    form.value.tagIds.splice(index, 1)
  } else {
    form.value.tagIds.push(tag.id as number)
  }
}

const showCreateButton = computed(() => {
  const query = tagSearchQuery.value.trim()
  if (!query) return false
  return !allTags.value.some(tag => tag.name.toLowerCase() === query.toLowerCase())
})

const createNewTag = async () => {
  const tagName = tagSearchQuery.value.trim()
  if (!tagName) return

  isCreatingTag.value = true
  try {
    // 调用Python后端API创建个人标签
    const result = await createPersonalTag({
      tag_name: tagName,
      parent_id: 0
    })

    // 创建成功后添加到本地列表并选中
    const newTag: TagItem = {
      id: result.tag_id,
      name: result.tag_name,
      parentId: 0,
      departmentId: undefined, // 新创建的标签默认没有关联部门
      children: []
    }

    allTags.value.push(newTag)
    form.value.tagIds.push(newTag.id as number)
    // 记录新创建的标签ID，保存时会更新其department_id
    newlyCreatedTagIds.value.push(result.tag_id)
    tagSearchQuery.value = ''

    toast('标签创建成功', 'success')
  } catch (error) {
    console.error('Failed to create tag:', error)
    toast('创建标签失败', 'error')
  } finally {
    isCreatingTag.value = false
  }
}

const selectedDeptName = computed(() => {
  if (form.value.departmentId === null) return '选择部门...'
  
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
    // 设置 promptId，如果会话已经关联了提示词，则使用它
    form.value.promptId = props.promptId || null

    const aiMessages = props.messages.filter(m => (m.role === 'ai' || m.role === 'assistant') && m.type !== 'welcome')
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
    // 重置标签公开选项为默认选中
    makeSelectedTagsPublic.value = true
  }
})

const aiMessages = computed(() => 
  props.messages.filter(m => (m.role === 'ai' || m.role === 'assistant') && m.type !== 'welcome')
)

const close = () => {
  emit('update:visible', false)
}

// 统一保存模式 - 任何情况都可以直接保存
const isStandaloneMode = computed(() => {
  return true
})

const canSave = computed(() => {
  return true
})

const handleSave = async () => {
  if (isSaving.value) return
  if (!form.value.title.trim()) {
    toast('请输入标题', 'warning')
    return
  }
  // 引用别人的提示词时，标题不能与原标题相同
  if (props.originalPromptTitle && form.value.title.trim() === props.originalPromptTitle.trim()) {
    toast('标题不能与原提示词相同，请修改标题', 'warning')
    return
  }
  if (form.value.visibility === 'plaza' && form.value.departmentId === null) {
    toast('请选择发布部门', 'warning')
    return
  }

  isSaving.value = true
  try {
    // 如果没有会话ID但有提示词ID（临时会话场景），需要先创建会话
    let sessionId = props.sessionId
    if (!sessionId && props.promptId) {
      const newSession = await createChatSession(form.value.title.trim())
      sessionId = newSession.session_id
      console.log(`[SavePromptModal] Created new session ${sessionId} for temp prompt ${props.promptId}`)
    }

    // 构建保存请求 - 统一使用直接保存模式
    const saveData: any = {
      title: form.value.title.trim(),
      source_type: 'prompt',  // 统一使用 prompt 来源
      visibility: form.value.visibility,
      tag_ids: form.value.tagIds || [],
      description: form.value.description || '',
      user_input_example: form.value.userInputExample || '',
      finalize_session: !!sessionId,  // 有会话ID时收敛会话，设置origin_prompt_id
      content: props.promptContent  // 直接传递提示词内容
    }

    // 如果有会话ID，也传递过去（用于关联会话）
    if (sessionId) {
      saveData.session_id = sessionId
    }
    
    if (form.value.visibility === 'plaza' && form.value.departmentId !== null) {
      saveData.department_id = form.value.departmentId
    }
    // 如果有关联的提示词ID，进行更新而不是新建
    if (form.value.promptId) {
      saveData.prompt_id = form.value.promptId
    }

    // 调用Python后端API保存
    const result = await savePromptFromStudio(saveData)

    // 如果保存的是公开提示词且用户选择将标签公开，则更新标签的department_id
    if (form.value.visibility === 'plaza' && form.value.departmentId !== null && makeSelectedTagsPublic.value) {
      // 收集需要公开化的标签ID：新创建的标签 + 选中的已存在私有标签
      const tagsToMakePublic: number[] = []

      // 1. 新创建的标签
      const selectedNewTagIds = form.value.tagIds.filter(tagId =>
        newlyCreatedTagIds.value.includes(tagId)
      )
      tagsToMakePublic.push(...selectedNewTagIds)

      // 2. 已存在的私有标签
      tagsToMakePublic.push(...selectedPrivateTagIds.value)

      if (tagsToMakePublic.length > 0) {
        console.log(`[SavePromptModal] 用户选择公开，更新 ${tagsToMakePublic.length} 个标签的部门ID为 ${form.value.departmentId}`)
        // 并行更新所有标签的department_id
        const updatePromises = tagsToMakePublic.map(tagId =>
          updateTagDepartment(tagId, form.value.departmentId!)
            .catch(err => console.error(`[SavePromptModal] 更新标签 ${tagId} 部门失败:`, err))
        )
        await Promise.all(updatePromises)
      }
    }

    // 根据保存类型显示不同的提示消息
    let successMsg = '提示词保存成功'
    if (result.is_forked) {
      successMsg = '已引用并创建新提示词'
    } else if (result.is_update) {
      successMsg = '提示词更新成功'
    }
    toast(successMsg, 'success')

    // 触发保存成功事件，传递新创建的sessionId（如果有）
    emit('saved', {
      ...result,
      session_id: sessionId,
      formData: form.value
    })

    // 关闭弹窗
    emit('update:visible', false)

    // 同时触发旧的save事件保持兼容性
    emit('save', {
      ...form.value,
      sessionId: sessionId,
      content: form.value.sourceType === 'prompt' ? props.promptContent : null,
      result
    })
  } catch (error: any) {
    console.error('Failed to save prompt:', error)
    // 根据错误类型显示友好的提示信息
    const status = error.response?.status
    let errorMsg = '保存失败，请稍后重试'
    if (status === 400) {
      errorMsg = '保存内容格式有误，请检查后重试'
    } else if (status === 401 || status === 403) {
      errorMsg = '登录已过期，请重新登录'
    } else if (status === 500) {
      errorMsg = '服务器繁忙，请稍后再试'
    } else if (!navigator.onLine) {
      errorMsg = '网络连接失败，请检查网络设置'
    }
    toast(errorMsg, 'error')
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
          <!-- 直接保存模式提示 -->
          <div class="session-info">
            <Info :size="16" class="info-icon" />
            <div class="info-content">
              <div class="info-title">直接保存模式</div>
              <div class="info-desc">保存后可在提示词库中查看。</div>
            </div>
          </div>
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

            <!-- 2. Source Type (仅对话模式显示) -->
            <div v-if="!isStandaloneMode" class="form-item">
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
              <div v-if="!isStandaloneMode && form.sourceType === 'reply'" class="form-item">
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
              <div class="tag-management-panel">
                <!-- Search / Create Bar -->
                <div class="tag-search-bar">
                  <Search :size="14" class="search-icon"/>
                  <input
                    v-model="tagSearchQuery"
                    type="text"
                    placeholder="搜索或创建新标签..."
                    @keyup.enter="createNewTag"
                  >
                  <button
                    v-if="showCreateButton"
                    class="quick-create-btn"
                    @click="createNewTag"
                    :disabled="isCreatingTag"
                  >
                    <Plus :size="14" />
                    创建 "{{ tagSearchQuery }}"
                  </button>
                </div>

                <!-- Available Tags List (Chips) -->
                <div class="tags-cloud custom-scrollbar">
                  <div v-if="isFetchingData && allTags.length === 0" class="loading-tags">
                    <Loader2 :size="16" class="animate-spin" />
                    <span>加载标签中...</span>
                  </div>
                  <template v-else>
                    <div
                      v-for="tag in filteredTags"
                      :key="tag.id"
                      class="tag-chip-option"
                      :class="{
                        selected: form.tagIds.includes(tag.id as number),
                        'is-public': tag.departmentId
                      }"
                      @click="toggleTag(tag)"
                    >
                      <span class="tag-name">{{ tag.name }}</span>
                      <span v-if="tag.departmentId" class="tag-status public">公开</span>
                      <span v-else class="tag-status private">私有</span>
                      <CheckCircle2 v-if="form.tagIds.includes(tag.id as number)" :size="12" class="tag-check" />
                      <Plus v-else :size="12" class="tag-plus" />
                    </div>
                    <div v-if="filteredTags.length === 0 && !showCreateButton" class="no-tags-hint">
                      暂无标签
                    </div>
                  </template>
                </div>

                <!-- 标签公开选项：当有选中的私有标签时显示 -->
                <div v-if="form.visibility === 'plaza' && selectedPrivateTagIds.length > 0" class="tag-public-option">
                  <label class="checkbox-label">
                    <input
                      type="checkbox"
                      v-model="makeSelectedTagsPublic"
                      class="checkbox-input"
                    >
                    <span class="checkbox-text">将选中的 {{ selectedPrivateTagIds.length }} 个私有标签设为公开</span>
                  </label>
                  <span class="option-hint">公开后其他用户可在提示词广场看到此标签</span>
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
                <!-- 只有一个选项时显示为只读文本 -->
                <div v-if="hasSingleDeptOption" class="single-dept-display">
                  <span class="dept-text">{{ selectedDeptName }}</span>
                </div>
                <!-- 多个选项时显示下拉框 -->
                <div v-else class="custom-tree-select" @click.stop>
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
                      <div class="tree-content custom-scrollbar">
                        <div v-if="isFetchingData && departments.length === 0" class="loading-tree">
                          <Loader2 :size="16" class="animate-spin" />
                          <span>加载部门中...</span>
                        </div>
                        <template v-else>
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
                        </template>
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
          <button 
            class="footer-btn primary" 
            @click="handleSave" 
            :disabled="isSaving"
          >
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
  will-change: transform, opacity;
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

/* 无会话ID警告样式 */
.session-warning {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 14px 16px;
  background: linear-gradient(135deg, #fef3c7 0%, #fde68a 100%);
  border: 1px solid #f59e0b;
  border-radius: var(--radius-sm);
  margin-bottom: 16px;
}

.warning-icon {
  color: #d97706;
  flex-shrink: 0;
  margin-top: 2px;
}

.warning-content {
  flex: 1;
  min-width: 0;
}

.warning-title {
  font-size: 14px;
  font-weight: 600;
  color: #92400e;
  margin-bottom: 4px;
}

.warning-desc {
    font-size: 13px;
    color: #a16207;
    line-height: 1.5;
}

/* 独立模式信息提示样式 */
.session-info {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 14px 16px;
    background: linear-gradient(135deg, #eff6ff 0%, #dbeafe 100%);
    border: 1px solid #3b82f6;
    border-radius: var(--radius-sm);
    margin-bottom: 16px;
}

.info-icon {
    color: #2563eb;
    flex-shrink: 0;
    margin-top: 2px;
}

.info-content {
    flex: 1;
    min-width: 0;
}

.info-title {
    font-size: 14px;
    font-weight: 600;
    color: #1e40af;
    margin-bottom: 4px;
}

.info-desc {
    font-size: 13px;
    color: #3b82f6;
    line-height: 1.5;
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

.tag-selection-container {
  border: 1px solid var(--border-light);
  border-radius: var(--radius-md);
  padding: 12px;
  background: var(--bg-surface);
}

.tag-management-panel {
  display: flex;
  flex-direction: column;
  gap: 12px;
}

.tag-search-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 10px;
  background: var(--bg-secondary);
  border-radius: var(--radius-sm);
  height: 36px;
  border: 1px solid transparent;
  transition: all 0.2s;
}

.tag-search-bar:focus-within {
  background: var(--bg-surface);
  border-color: var(--primary);
  box-shadow: 0 0 0 2px rgba(59, 130, 246, 0.1);
}

.search-icon {
  color: var(--text-tertiary);
}

.tag-search-bar input {
  flex: 1;
  background: transparent;
  border: none;
  font-size: 13px;
  color: var(--text-primary);
  outline: none;
  min-width: 0;
}

.quick-create-btn {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  background: var(--primary-light);
  color: var(--primary);
  border: none;
  border-radius: 4px;
  font-size: 12px;
  cursor: pointer;
  white-space: nowrap;
  transition: all 0.2s;
}

.quick-create-btn:hover {
  background: var(--primary);
  color: white;
}

.tags-cloud {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  max-height: 150px;
  overflow-y: auto;
  padding: 2px;
}

.tag-chip-option {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: 100px;
  font-size: 12px;
  color: var(--text-secondary);
  cursor: pointer;
  transition: all 0.2s;
  user-select: none;
}

.tag-chip-option:hover {
  background: var(--bg-primary);
  border-color: var(--text-tertiary);
  color: var(--text-primary);
}

.tag-chip-option.selected {
  background: var(--primary-light);
  border-color: var(--primary);
  color: var(--primary);
}

.tag-check {
  color: var(--primary);
}

.tag-plus {
  color: var(--text-tertiary);
  opacity: 0.5;
}

.tag-chip-option:hover .tag-plus {
  opacity: 1;
  color: var(--text-secondary);
}

/* 标签状态样式 */
.tag-chip-option .tag-name {
  flex: 1;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.tag-chip-option .tag-status {
  font-size: 10px;
  padding: 1px 5px;
  border-radius: 100px;
  font-weight: 500;
  margin-right: 4px;
}

.tag-chip-option .tag-status.public {
  background: rgba(34, 197, 94, 0.15);
  color: #16a34a;
}

.tag-chip-option .tag-status.private {
  background: rgba(156, 163, 175, 0.15);
  color: #6b7280;
}

.tag-chip-option.selected .tag-status.public {
  background: rgba(34, 197, 94, 0.25);
  color: #15803d;
}

.tag-chip-option.selected .tag-status.private {
  background: rgba(59, 130, 246, 0.2);
  color: var(--primary);
}

.no-tags-hint {
  width: 100%;
  text-align: center;
  padding: 12px;
  color: var(--text-tertiary);
  font-size: 12px;
  font-style: italic;
}

/* 标签公开选项样式 */
.tag-public-option {
  margin-top: 12px;
  padding: 10px 12px;
  background: var(--bg-secondary);
  border: 1px solid var(--border-light);
  border-radius: var(--radius-sm);
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 8px;
  cursor: pointer;
}

.checkbox-input {
  width: 16px;
  height: 16px;
  cursor: pointer;
  accent-color: var(--primary);
}

.checkbox-text {
  font-size: 13px;
  color: var(--text-primary);
  font-weight: 500;
}

.option-hint {
  font-size: 11px;
  color: var(--text-tertiary);
  margin-left: 24px;
  line-height: 1.4;
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

/* 单个部门只读显示样式 */
.single-dept-display {
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
}

.single-dept-display .dept-text {
  color: var(--text-primary);
  font-weight: 500;
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

.dropdown-fade-enter-active,
.dropdown-fade-leave-active {
  transition: all 0.2s ease;
}

.dropdown-fade-enter-from,
.dropdown-fade-leave-to {
  opacity: 0;
  transform: translateY(-5px);
}

.loading-tags,
.loading-tree {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 20px;
  color: var(--text-tertiary);
  font-size: 13px;
}

.animate-spin {
  animation: spin 1s linear infinite;
}
</style>

<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch, inject, computed, nextTick, onActivated, onDeactivated } from 'vue'
import { useRouter } from 'vue-router'
import { Search, ArrowUpDown, Box, Heart, Eye, User, ThumbsUp, Maximize2, CheckSquare, Square, Link, Settings, MoreVertical, X, Share2, Trash2, Tag, Plus } from 'lucide-vue-next'
import * as LucideIcons from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'
import PromptDetailModal from '@/components/common/PromptDetailModal.vue'
import PromptSkeleton from '@/components/ui/Skeleton/PromptSkeleton.vue'
import { getPrompts, toggleFavorite, toggleLike, getPromptDetail, batchSharePrompts, batchUnsharePrompts } from '@/api/prompt'
import { deletePrompt, addTagToPrompt, getPromptSession, removeTagFromPrompt, getPythonTagsTree, getPythonDepartmentsTree } from '@/api/promptSave'
import { useToast } from '@/composables/useToast'
import { useUserStore } from '@/stores/user'
import { useChatStore } from '@/stores/chat'
import type { PromptItem } from '@/types/prompt'
import type { TagNode } from '@/api/promptSave'

const props = defineProps<{
  isSidebarCollapsed?: boolean
  tagId?: number | number[] | null
  deptId?: number | null
  filter?: string
  sort?: string
  search?: string
  hideToolbar?: boolean
  showQuoteAction?: boolean
  isMyPrompts?: boolean
}>()

const emit = defineEmits<{
  (e: 'promptsDeleted', promptIds: number[]): void
  (e: 'promptsShared', promptIds: number[]): void
  (e: 'promptsUnshared', promptIds: number[]): void
}>()

const router = useRouter()
const { toast } = useToast()
const userStore = useUserStore()
const chatStore = useChatStore()
const searchQuery = ref('')
const activeFilter = ref(props.filter || 'all')
const sortBy = ref('updatedAt')
const searchInputRef = ref<HTMLInputElement | null>(null)
const prompts = ref<PromptItem[]>([])
const loading = ref(false)
const fetchId = ref(0)
const lastQueryKey = ref<string | null>(null)
const total = ref(0)
const currentPage = ref(1)
const pageSize = ref(12)
const showDetailModal = ref(false)
const selectedPromptId = ref<number | null>(null)
const selectedPromptData = ref<PromptItem | null>(null)
const navigatingId = ref<number | null>(null)

// 注入模式状态
const isDeleteMode = inject<Ref<boolean>>('isDeleteMode', ref(false))
const isShareMode = inject<Ref<boolean>>('isShareMode', ref(false))
const isBatchTagMode = inject<Ref<boolean>>('isBatchTagMode', ref(false))
const selectedPrompts = inject<Ref<Set<number>>>('selectedPrompts', ref(new Set()))
const togglePromptSelection = inject<(promptId: number) => void>('togglePromptSelection', () => {})

// 设置菜单相关状态
const activeSettingsPromptId = ref<number | null>(null)
const showSettingsMenu = ref(false)
const settingsMenuPosition = ref({ x: 0, y: 0 })
const showTagManageModal = ref(false)
const tagManagePrompt = ref<PromptItem | null>(null)
const userTags = ref<TagNode[]>([])
const loadingTags = ref(false)
// 用于防止重复添加标签的 Set，存储正在添加的标签ID
const addingTagIds = ref<Set<number>>(new Set())

// 删除确认弹窗
const showDeleteConfirmModal = ref(false)
const promptToDelete = ref<PromptItem | null>(null)
const deleteWithSession = ref(false)

// 分享确认弹窗
const showShareConfirmModal = ref(false)
const promptToShare = ref<PromptItem | null>(null)
const shareScope = ref<'all' | 'department'>('all')
const departments = ref<any[]>([])
const selectedDepartment = ref<number | null>(null)
const loadingDepartments = ref(false)

// 当前用户ID
const currentUserId = computed(() => userStore.userInfo?.id || null)

// 判断是否为当前用户的提示词
const isOwnPrompt = (prompt: PromptItem): boolean => {
  if (!currentUserId.value) return false
  // 使用字符串比较，避免类型不一致的问题
  return String(currentUserId.value) === String(prompt.author?.id)
}

// 暴露方法给父组件
const deleteSelectedPrompts = async (deleteWithSession = false): Promise<number[]> => {
  const idsToDelete = Array.from(selectedPrompts.value)
  if (idsToDelete.length === 0) return []
  
  const deletedIds: number[] = []
  
  for (const promptId of idsToDelete) {
    try {
      await deletePrompt(promptId, deleteWithSession)
      deletedIds.push(promptId)
    } catch (error: any) {
      console.error(`Failed to delete prompt ${promptId}:`, error)
    }
  }
  
  // 从列表中移除已删除的
  prompts.value = prompts.value.filter(p => !deletedIds.includes(p.id))
  total.value -= deletedIds.length
  
  // 清空选择
  selectedPrompts.value.clear()
  
  if (deletedIds.length > 0) {
    toast(`成功删除 ${deletedIds.length} 个提示词`, 'success')
    emit('promptsDeleted', deletedIds)
  }
  
  return deletedIds
}

const shareSelectedPrompts = async (deptId?: number): Promise<number[]> => {
  const idsToShare = Array.from(selectedPrompts.value)
  if (idsToShare.length === 0) return []

  try {
    await batchSharePrompts(idsToShare, deptId)
    
    // 清空选择
    selectedPrompts.value.clear()
    
    toast(`成功分享 ${idsToShare.length} 个提示词`, 'success')
    emit('promptsShared', idsToShare)
    
    return idsToShare
  } catch (error: any) {
    console.error(`Failed to share prompts:`, error)
    toast('分享失败，请重试', 'error')
    return []
  }
}

// 取消分享单个提示词
const handleUnshare = async (prompt: PromptItem) => {
  try {
    await batchUnsharePrompts([prompt.id])

    // 从列表中移除
    prompts.value = prompts.value.filter(p => p.id !== prompt.id)
    total.value -= 1

    toast('已取消分享', 'success')
    emit('promptsUnshared', [prompt.id])
  } catch (error: any) {
    console.error('Failed to unshare prompt:', error)
    toast(error?.response?.data?.message || '取消分享失败，请重试', 'error')
  }
}

// ============ 设置菜单功能 ============

// 显示设置菜单
const showSettings = (e: MouseEvent, prompt: PromptItem) => {
  e.stopPropagation()
  const rect = (e.currentTarget as HTMLElement).getBoundingClientRect()
  settingsMenuPosition.value = {
    x: rect.left - 140,
    y: rect.bottom + 8
  }
  activeSettingsPromptId.value = prompt.id
  showSettingsMenu.value = true
}

// 关闭设置菜单
const closeSettingsMenu = () => {
  showSettingsMenu.value = false
  activeSettingsPromptId.value = null
}

// 点击外部关闭设置菜单
const handleClickOutside = (e: MouseEvent) => {
  if (showSettingsMenu.value) {
    closeSettingsMenu()
  }
}

// 打开标签管理弹窗
const openTagManage = async (prompt: PromptItem) => {
  closeSettingsMenu()
  tagManagePrompt.value = prompt
  showTagManageModal.value = true
  loadingTags.value = true
  try {
    const res = await getPythonTagsTree(true)
    // 只加载个人标签，不显示系统标签
    const allTags: TagNode[] = []
    const flattenTags = (nodes: TagNode[]) => {
      nodes.forEach(node => {
        allTags.push(node)
        if (node.children && node.children.length > 0) {
          flattenTags(node.children)
        }
      })
    }
    // 只加载个人标签
    if (res.personal_tags) flattenTags(res.personal_tags)
    userTags.value = allTags
  } catch (error) {
    console.error('Failed to load tags:', error)
    toast('加载标签失败', 'error')
  } finally {
    loadingTags.value = false
  }
}

// 关闭标签管理弹窗
const closeTagManage = () => {
  showTagManageModal.value = false
  tagManagePrompt.value = null
  userTags.value = []
}

// 检查标签是否已关联到提示词
const isTagAssociated = (tagId: number): boolean => {
  if (!tagManagePrompt.value) return false
  // 这里需要根据实际数据结构来判断
  // 暂时通过标签名称来匹配
  const tag = userTags.value.find(t => t.id === tagId)
  if (!tag) return false
  return tagManagePrompt.value.tags.includes(tag.tag_name)
}

// 添加标签到提示词
const handleAddTagToPrompt = async (tagId: number) => {
  if (!tagManagePrompt.value) return
  const tag = userTags.value.find(t => t.id === tagId)
  if (!tag) return

  // 检查是否已存在
  if (isTagAssociated(tagId)) {
    toast('该标签已关联', 'info')
    return
  }

  // 防重复：检查是否正在添加该标签
  if (addingTagIds.value.has(tagId)) {
    console.log('[PromptList] Tag is already being added:', tagId)
    return
  }

  // 添加到处理中集合，防止重复
  addingTagIds.value.add(tagId)

  try {
    await addTagToPrompt(tagManagePrompt.value.id, tagId)
    // 乐观更新（tagManagePrompt 和 prompts 中的对象是同一个引用，只需添加一次）
    tagManagePrompt.value.tags.push(tag.tag_name)
    toast(`已添加标签「${tag.tag_name}」`, 'success')
  } catch (error: any) {
    toast(error?.response?.data?.message || '添加标签失败', 'error')
  } finally {
    // 无论成功失败，都从处理中集合移除
    addingTagIds.value.delete(tagId)
  }
}

// 从提示词移除标签
const handleRemoveTagFromPrompt = async (tagName: string) => {
  if (!tagManagePrompt.value) return

  const tag = userTags.value.find(t => t.tag_name === tagName)
  if (!tag) {
    // 如果找不到标签对象，直接从UI移除
    const index = tagManagePrompt.value.tags.indexOf(tagName)
    if (index > -1) {
      tagManagePrompt.value.tags.splice(index, 1)
    }
    const promptInList = prompts.value.find(p => p.id === tagManagePrompt.value!.id)
    if (promptInList) {
      const listIndex = promptInList.tags.indexOf(tagName)
      if (listIndex > -1) {
        promptInList.tags.splice(listIndex, 1)
      }
    }
    return
  }

  try {
    // 调用API移除标签
    await removeTagFromPrompt(tagManagePrompt.value.id, tag.id)
    // 乐观更新
    const index = tagManagePrompt.value.tags.indexOf(tagName)
    if (index > -1) {
      tagManagePrompt.value.tags.splice(index, 1)
    }
    const promptInList = prompts.value.find(p => p.id === tagManagePrompt.value!.id)
    if (promptInList) {
      const listIndex = promptInList.tags.indexOf(tagName)
      if (listIndex > -1) {
        promptInList.tags.splice(listIndex, 1)
      }
    }
    toast(`已移除标签「${tagName}」`, 'success')
  } catch (error: any) {
    toast(error?.response?.data?.message || '移除标签失败', 'error')
  }
}

// 打开删除确认弹窗
const openDeleteConfirm = (prompt: PromptItem) => {
  closeSettingsMenu()
  promptToDelete.value = prompt
  deleteWithSession.value = false
  showDeleteConfirmModal.value = true
}

// 关闭删除确认弹窗
const closeDeleteConfirm = () => {
  showDeleteConfirmModal.value = false
  promptToDelete.value = null
  deleteWithSession.value = false
}

// 执行删除
const executeDeletePrompt = async () => {
  if (!promptToDelete.value) return

  try {
    await deletePrompt(promptToDelete.value.id, deleteWithSession.value)
    // 从列表中移除
    prompts.value = prompts.value.filter(p => p.id !== promptToDelete.value!.id)
    total.value -= 1
    toast('删除成功', 'success')
    emit('promptsDeleted', [promptToDelete.value.id])
  } catch (error: any) {
    toast(error?.response?.data?.message || '删除失败', 'error')
  } finally {
    closeDeleteConfirm()
  }
}

// 打开分享确认弹窗
const openShareConfirm = async (prompt: PromptItem) => {
  closeSettingsMenu()
  promptToShare.value = prompt
  shareScope.value = 'all'
  selectedDepartment.value = null
  showShareConfirmModal.value = true

  // 加载部门列表（只显示全部部门和用户自己的部门）
  loadingDepartments.value = true
  try {
    const depts = await getPythonDepartmentsTree()
    departments.value = filterDepartmentsForShare(depts)
  } catch (error) {
    console.error('Failed to load departments:', error)
  } finally {
    loadingDepartments.value = false
  }
}

// 过滤部门：只显示全部部门(ID=1)和用户自己的部门
const filterDepartmentsForShare = (nodes: any[]): any[] => {
  const ALL_DEPT_ID = 1 // "全部部门"在数据库中的ID
  const userDeptId = userStore.userInfo?.departmentId ?? userStore.userInfo?.department_id ?? null

  // 从树中查找指定ID的部门
  const findDeptById = (nodes: any[], targetId: number): any | null => {
    for (const node of nodes) {
      const nodeId = node.id ?? node.department_id
      if (nodeId === targetId) {
        return node
      }
      if (node.children && node.children.length > 0) {
        const found = findDeptById(node.children, targetId)
        if (found) return found
      }
    }
    return null
  }

  const result: any[] = []

  // 1. 添加"全部部门"
  const allDept = findDeptById(nodes, ALL_DEPT_ID)
  if (allDept) {
    result.push({
      ...allDept,
      displayName: allDept.name || allDept.department_name || '全部部门'
    })
  }

  // 2. 如果用户有绑定部门且不是全部部门，添加所属部门
  if (userDeptId !== null && userDeptId !== ALL_DEPT_ID) {
    const userDept = findDeptById(nodes, userDeptId)
    if (userDept) {
      result.push({
        ...userDept,
        displayName: userDept.name || userDept.department_name || '我的部门'
      })
    }
  }

  return result
}

// 关闭分享确认弹窗
const closeShareConfirm = () => {
  showShareConfirmModal.value = false
  promptToShare.value = null
  shareScope.value = 'all'
  selectedDepartment.value = null
  departments.value = []
}

// 执行分享
const executeSharePrompt = async () => {
  if (!promptToShare.value) return

  // 如果选择了指定部门但没有选部门，提示错误
  if (shareScope.value === 'department' && !selectedDepartment.value) {
    toast('请选择要分享的部门', 'warning')
    return
  }

  try {
    // 调用分享API，传入部门ID（如果选择了指定部门）
    const deptId = shareScope.value === 'department' ? selectedDepartment.value : undefined
    await batchSharePrompts([promptToShare.value.id], deptId)
    toast('分享成功', 'success')
    emit('promptsShared', [promptToShare.value.id])
  } catch (error: any) {
    toast(error?.response?.data?.message || '分享失败', 'error')
  } finally {
    closeShareConfirm()
  }
}

const filters = [
  { id: 'all', label: '全部' },
  { id: 'my', label: '私有提示词' },
  { id: 'favorites', label: '我的收藏' },
  { id: 'shared', label: '公共分享' }
]

const sortOptions = [
  { value: 'updatedAt', label: '最近更新' },
  { value: 'createdAt', label: '创建时间' },
  { value: 'views', label: '最多浏览' },
  { value: 'likes', label: '最多收藏' }
]

const formatTimeAgo = (dateStr: string) => {
  const date = new Date(dateStr)
  const now = new Date()
  const diffInSeconds = Math.floor((now.getTime() - date.getTime()) / 1000)
  
  if (diffInSeconds < 60) return '刚刚'
  if (diffInSeconds < 3600) return `${Math.floor(diffInSeconds / 60)}分钟前`
  if (diffInSeconds < 86400) return `${Math.floor(diffInSeconds / 3600)}小时前`
  if (diffInSeconds < 604800) return `${Math.floor(diffInSeconds / 86400)}天前`
  return date.toLocaleDateString()
}

const loadMoreTrigger = ref<HTMLElement | null>(null)
let observer: IntersectionObserver | null = null

// Virtual Scroll Logic removed

const setActiveFilter = (filter: string) => {
  activeFilter.value = filter
}

const getQueryKey = () => {
  return JSON.stringify({
    keyword: props.search !== undefined ? props.search : searchQuery.value,
    filter: activeFilter.value,
    sort: props.sort || sortBy.value,
    tagId: props.tagId,
    deptId: props.deptId ?? null
  })
}

const fetchPromptsList = async (append = false) => {
  // 如果是加载更多，且正在加载，则忽略
  if (append && loading.value) return

  const currentFetchId = ++fetchId.value
  
  if (!append) {
    loading.value = true
  }
  
  try {
    const queryKey = getQueryKey()
    const res = await getPrompts({
      page: currentPage.value,
      pageSize: pageSize.value,
      keyword: props.search !== undefined ? props.search : searchQuery.value,
      filter: (activeFilter.value) as any,
      sort: (props.sort || sortBy.value) as any,
      order: 'desc',
      tagId: props.tagId,
      deptId: props.deptId
    })
    
    // 检查是否是最新请求
    if (currentFetchId !== fetchId.value) return

    if (!append && res.list.length === 0 && res.total > 0 && currentPage.value > 1) {
      currentPage.value = 1
      await fetchPromptsList(false)
      return
    }

    if (append) {
      prompts.value = [...prompts.value, ...res.list]
    } else {
      prompts.value = res.list
    }
    total.value = res.total
    if (!append) {
      lastQueryKey.value = queryKey
    }
  } catch (error) {
    if (currentFetchId === fetchId.value) {
      console.error('Failed to fetch prompts:', error)
    }
  } finally {
    if (currentFetchId === fetchId.value) {
      loading.value = false
    }
  }
}

defineExpose({
  deleteSelectedPrompts,
  shareSelectedPrompts,
  fetchPromptsList,
  setActiveFilter,
  prompts
})

// Watchers for refetching
watch([activeFilter, sortBy], ([newFilter, newSort], [oldFilter, oldSort]) => {
  // Check if the change should be ignored
  const filterChanged = newFilter !== oldFilter
  const sortChanged = newSort !== oldSort
  
  // If external filter provided, ignore internal filter changes
  // if (filterChanged && props.filter) return
  
  // If external sort provided, ignore internal sort changes
  if (sortChanged && props.sort) return

  currentPage.value = 1
  fetchPromptsList(false)
})

watch(() => props.filter, (newFilter) => {
  if (newFilter) {
    activeFilter.value = newFilter
  }
})

watch(() => [props.tagId, props.deptId, props.sort, props.search], () => {
  currentPage.value = 1
  fetchPromptsList(false)
}, { immediate: true })

let searchTimeout: ReturnType<typeof setTimeout>
watch(searchQuery, () => {
  clearTimeout(searchTimeout)
  searchTimeout = setTimeout(() => {
    currentPage.value = 1
    fetchPromptsList(false)
  }, 300)
})

const setupObserver = () => {
  if (observer) {
    observer.disconnect()
  }
  observer = new IntersectionObserver((entries) => {
    const entry = entries[0]
    if (entry && entry.isIntersecting && !loading.value && prompts.value.length < total.value) {
      currentPage.value++
      fetchPromptsList(true)
    }
  }, {
    rootMargin: '200px', // 提前 200px 加载
    threshold: 0.1
  })

  if (loadMoreTrigger.value) {
    observer.observe(loadMoreTrigger.value)
  }
}

watch(loadMoreTrigger, (el) => {
  if (el && observer) {
    observer.disconnect()
    observer.observe(el)
  }
})

const getTagTone = (tag: string) => {
  const t = tag.toLowerCase()

  const tech = ['python', 'vue', 'typescript', 'sql', 'pandas', 'web', '前端', '后端', '数据库', '数据', '开发']
  const writing = ['写作', '文案', '周报', '办公', '邮件', '报告', '效率']
  const creative = ['ai绘画', 'midjourney', '设计', '创意', '故事', '绘画']
  const business = ['商业', '运营', '营销', '产品', '增长']

  if (tech.some((k) => t.includes(k))) return 'tag--blue'
  if (writing.some((k) => t.includes(k))) return 'tag--purple'
  if (creative.some((k) => t.includes(k))) return 'tag--amber'
  if (business.some((k) => t.includes(k))) return 'tag--emerald'
  return 'tag--gray'
}

const getPromptEmoji = (tags: string[]) => {
  const joined = tags.join(' ').toLowerCase()
  if (joined.includes('python')) return '🐍'
  if (joined.includes('vue')) return '🟢'
  if (joined.includes('sql')) return '🗄️'
  if (joined.includes('数据') || joined.includes('pandas')) return '📊'
  if (joined.includes('写作') || joined.includes('周报') || joined.includes('文案')) return '✍️'
  if (joined.includes('ai绘画') || joined.includes('midjourney') || joined.includes('设计')) return '🎨'
  return '✨'
}

const getIconComponent = (iconName: string) => {
  if (!iconName) return LucideIcons.Sparkles
  return (LucideIcons as any)[iconName] || LucideIcons.Sparkles
}

const handleCardClick = async (prompt: PromptItem) => {
  // 批量操作模式下点击卡片切换选择状态
  if (isDeleteMode.value || isShareMode.value || isBatchTagMode.value) {
    togglePromptSelection(prompt.id)
    return
  }

  // 防止重复点击
  if (navigatingId.value) return
  navigatingId.value = prompt.id

  try {
    // 如果是当前用户的提示词，尝试获取关联的会话
    if (isOwnPrompt(prompt)) {
      try {
        const res = await getPromptSession(prompt.id)
        if (res && res.code === 0 && res.data?.session_id) {
          // 清理之前的会话状态，避免残留
          chatStore.openDraftSession()
          
          // 有关联的会话，跳转到该会话
          await router.push({
            path: '/studio',
            query: {
              session_id: res.data.session_id
            }
          })
          return
        }
      } catch (error) {
        console.error('Failed to get prompt session:', error)
      }
    }

    // 没有关联的会话或者是他人的提示词，按原有逻辑跳转
    // 清理之前的会话状态，避免残留
    chatStore.openDraftSession()

    // 使用 state 传递预加载数据，优化体验
    await router.push({
      path: '/studio',
      query: {
        promptId: prompt.id
      },
      state: {
        initialContent: prompt.content,
        initialTitle: prompt.title,
        initialPrompt: JSON.parse(JSON.stringify(prompt)) // 传递完整对象以备用
      }
    })
  } finally {
    navigatingId.value = null
  }
}

const openDetailModal = (prompt: PromptItem) => {
  selectedPromptId.value = prompt.id
  selectedPromptData.value = prompt
  showDetailModal.value = true
}

const handleToggleFavorite = async (prompt: PromptItem) => {
  const newStatus = !prompt.isFavorited
  // Optimistic update
  prompt.isFavorited = newStatus
  prompt.stats.favorites = (prompt.stats.favorites || 0) + (newStatus ? 1 : -1)
  
  try {
    await toggleFavorite(prompt.id)
  } catch (error) {
    // Revert on error
    prompt.isFavorited = !newStatus
    prompt.stats.favorites = (prompt.stats.favorites || 0) + (!newStatus ? 1 : -1)
    console.error('Failed to toggle favorite:', error)
  }
}

const handleToggleLike = async (prompt: PromptItem) => {
  const newStatus = !prompt.isLiked
  // Optimistic update
  prompt.isLiked = newStatus
  prompt.stats.likes = (prompt.stats.likes || 0) + (newStatus ? 1 : -1)
  
  try {
    await toggleLike(prompt.id)
  } catch (error) {
    // Revert on error
    prompt.isLiked = !newStatus
    prompt.stats.likes = (prompt.stats.likes || 0) + (!newStatus ? 1 : -1)
    console.error('Failed to toggle like:', error)
  }
}

const handlePromptUpdate = (updatedPrompt: PromptItem) => {
  const index = prompts.value.findIndex(p => p.id === updatedPrompt.id)
  if (index !== -1) {
    prompts.value[index] = updatedPrompt
  }
}

// 拖拽相关状态
const dragOverPromptId = ref<number | null>(null)
// 用于防止重复添加标签的 Set，存储 "promptId:tagId" 格式的字符串
const addingTags = ref<Set<string>>(new Set())

// 处理拖拽进入卡片
const handleDragEnter = (e: DragEvent, prompt: PromptItem) => {
  // 只有自己的提示词才允许拖拽添加标签
  if (!isOwnPrompt(prompt)) return
  e.preventDefault()
  console.log('[PromptList] Drag enter:', prompt.id, prompt.title)
  dragOverPromptId.value = prompt.id
}

// 处理拖拽在卡片上移动
const handleDragOver = (e: DragEvent) => {
  e.preventDefault()
  if (e.dataTransfer) {
    e.dataTransfer.dropEffect = 'copy'
  }
}

// 处理拖拽离开卡片
const handleDragLeave = (e: DragEvent, prompt: PromptItem) => {
  e.preventDefault()
  // 检查是否真的离开了卡片（而不是进入子元素）
  const relatedTarget = e.relatedTarget as HTMLElement
  const currentTarget = e.currentTarget as HTMLElement
  if (relatedTarget && currentTarget.contains(relatedTarget)) {
    return
  }
  if (dragOverPromptId.value === prompt.id) {
    console.log('[PromptList] Drag leave:', prompt.id)
    dragOverPromptId.value = null
  }
}

// 处理放置标签到卡片
const handleDrop = async (e: DragEvent, prompt: PromptItem) => {
  // 只有自己的提示词才允许拖拽添加标签
  if (!isOwnPrompt(prompt)) return
  e.preventDefault()
  console.log('[PromptList] Drop on:', prompt.id, prompt.title)
  dragOverPromptId.value = null

  // 在函数顶部声明变量，确保 finally 块可以访问
  let tagId: number | null = null
  let tagName: string = ''
  let addingKey: string = ''

  try {
    // 获取拖拽数据
    let data = e.dataTransfer?.getData('application/json')
    if (!data) {
      data = e.dataTransfer?.getData('text/plain')
    }
    console.log('[PromptList] Drop data:', data)
    if (!data) {
      console.log('[PromptList] No drop data found')
      return
    }

    const parsedData = JSON.parse(data)
    tagId = parsedData.tagId
    tagName = parsedData.tagName
    console.log('[PromptList] Parsed data:', { tagId, tagName })
    if (!tagId) {
      console.log('[PromptList] No tagId in data')
      return
    }

    // 检查标签是否已存在
    if (prompt.tags.includes(tagName)) {
      toast('该提示词已拥有此标签', 'info')
      return
    }

    // 防重复：检查是否正在添加该标签
    addingKey = `${prompt.id}:${tagId}`
    if (addingTags.value.has(addingKey)) {
      console.log('[PromptList] Tag is already being added:', addingKey)
      return
    }

    // 添加到处理中集合，防止重复
    addingTags.value.add(addingKey)

    // 乐观更新：先在UI上添加标签
    prompt.tags.push(tagName)
    toast(`正在添加标签「${tagName}」...`, 'info')

    // 调用API添加标签
    const promptId = Number(prompt.id)
    console.log('[PromptList] Calling API to add tag:', { promptId, tagId })
    const res = await addTagToPrompt(promptId, tagId)
    console.log('[PromptList] API response:', res)

    // API 成功返回（request.ts 拦截器会在成功时直接返回 data）
    if (res && res.tag_id) {
      toast(`成功添加标签「${tagName}」`, 'success')
    } else {
      // API返回失败，回滚
      const index = prompt.tags.indexOf(tagName)
      if (index > -1) {
        prompt.tags.splice(index, 1)
      }
      toast('添加标签失败', 'error')
    }
  } catch (error: any) {
    console.error('[PromptList] Drop error:', error)
    // 发生错误，回滚乐观更新
    if (tagName) {
      const index = prompt.tags.indexOf(tagName)
      if (index > -1) {
        prompt.tags.splice(index, 1)
      }
    }
    const message = error?.response?.data?.message || '添加标签失败'
    toast(message, 'error')
  } finally {
    // 无论成功失败，都从处理中集合移除
    if (addingKey) {
      addingTags.value.delete(addingKey)
    }
  }
}

const onGlobalKeydown = (e: KeyboardEvent) => {
  const key = e.key.toLowerCase()
  const isK = key === 'k'
  const modifierPressed = e.ctrlKey || e.metaKey
  if (!modifierPressed || !isK) return

  e.preventDefault()
  searchInputRef.value?.focus()
}

onMounted(() => {
  window.addEventListener('keydown', onGlobalKeydown)
  window.addEventListener('click', handleClickOutside)
  // Ensure we start at the top
  // window.scrollTo(0, 0)
  // fetchPromptsList(false) // Removed: handled by immediate watch
  setupObserver()
})

onActivated(() => {
  setupObserver()
  const currentKey = getQueryKey()
  if (prompts.value.length > 0 && lastQueryKey.value === currentKey) return
  if (loading.value) return
  currentPage.value = 1
  fetchPromptsList(false)
})

onDeactivated(() => {
  if (observer) {
    observer.disconnect()
  }
})

onBeforeUnmount(() => {
  window.removeEventListener('keydown', onGlobalKeydown)
  window.removeEventListener('click', handleClickOutside)
  if (observer) {
    observer.disconnect()
  }
})
</script>

<template>
  <div class="prompt-list-container">
    <!-- Toolbar -->
    <div class="toolbar" v-if="!hideToolbar">
      <div class="search-section">
        <div class="search-input-wrapper">
          <Search class="search-icon" :size="20" />
          <input 
            type="text" 
            v-model="searchQuery" 
            placeholder="在列表中搜索..."
            class="main-search-input"
            ref="searchInputRef"
          >
          <div class="search-shortcut" aria-hidden="true">
            <kbd>Ctrl</kbd>
            <span class="kbd-plus">+</span>
            <kbd>K</kbd>
          </div>
        </div>
      </div>
      
      <div class="filter-section">
        <div class="filter-tabs">
          <button 
            v-for="filter in filters" 
            :key="filter.id"
            class="filter-tab"
            :class="{ active: activeFilter === filter.id }"
            @click="activeFilter = filter.id"
          >
            {{ filter.label }}
          </button>
        </div>
        
        <div class="sort-selector">
          <span class="sort-label">排序:</span>
          <div class="select-wrapper">
            <select v-model="sortBy" class="sort-select">
              <option v-for="opt in sortOptions" :key="opt.value" :value="opt.value">
                {{ opt.label }}
              </option>
            </select>
            <ArrowUpDown class="select-icon" :size="14" />
          </div>
        </div>
      </div>
    </div>

    <!-- Stats Bar -->
    <div class="stats-bar">
      <div class="stat-item">
        <Box :size="16" />
        <span>共 {{ total }} 个提示词</span>
      </div>
    </div>

    <!-- Grid -->
    <div v-if="loading && prompts.length === 0" class="prompt-grid">
      <PromptSkeleton v-for="i in 8" :key="i" />
    </div>
    <div v-else-if="prompts.length" class="prompt-grid" :class="{ 'sidebar-collapsed': isSidebarCollapsed, 'delete-mode': isDeleteMode || isShareMode || isBatchTagMode }">
      <div
        v-for="prompt in prompts"
        :key="prompt.id"
        class="prompt-card"
              :class="{
                'selected': selectedPrompts.has(prompt.id),
                'delete-mode': isDeleteMode || isShareMode || isBatchTagMode,
                'drag-over': dragOverPromptId === prompt.id,
                'is-own': isOwnPrompt(prompt) && filter === 'plaza'
              }"
              @dragenter="handleDragEnter($event, prompt)"
              @dragover="handleDragOver"
              @dragleave="handleDragLeave($event, prompt)"
              @drop="handleDrop($event, prompt)"
              @click="handleCardClick(prompt)"
            >
              <!-- Loading Overlay -->
              <div v-if="navigatingId === prompt.id" class="card-loading-overlay">
                <div class="spinner"></div>
              </div>

              <!-- 属于我的提示词标识 -->
              <div v-if="isOwnPrompt(prompt) && filter === 'plaza'" class="own-badge">
                <User :size="10" />
                <span>我的</span>
              </div>
              <!-- 批量操作模式选择框 -->
              <div
                v-if="isDeleteMode || isShareMode || isBatchTagMode"
                class="selection-indicator"
                :class="{ checked: selectedPrompts.has(prompt.id) }"
                @click.stop="togglePromptSelection(prompt.id)"
              >
                <CheckSquare v-if="selectedPrompts.has(prompt.id)" :size="24" class="checked" />
                <Square v-else :size="24" class="unchecked" />
              </div>
              <div class="card-header">
                <div class="header-top">
                  <div class="actions" v-if="!isDeleteMode && !isShareMode">
                    <!-- 广场模式 & 我的提示词模式：统一使用“图标+数值”合并布局 -->
                    <template v-if="filter === 'plaza' || filter !== 'plaza'">
                      <button class="action-btn-with-stat" title="查看详情" @click.stop="openDetailModal(prompt)">
                        <Eye :size="16" />
                        <span class="stat-num">{{ prompt.stats.views }}</span>
                      </button>
                      
                      <!-- 点赞按钮：广场模式可交互，非广场模式（如我的提示词）仅显示数值 -->
                      <button 
                        class="action-btn-with-stat" 
                        :class="{ 
                          'liked': prompt.isLiked && !isMyPrompts,
                          'no-interact': filter !== 'plaza' 
                        }" 
                        :title="filter === 'plaza' ? '点赞' : '点赞数'" 
                        @click.stop="filter === 'plaza' ? handleToggleLike(prompt) : null"
                      >
                        <ThumbsUp :size="16" :fill="(prompt.isLiked && !isMyPrompts) ? 'currentColor' : 'none'" />
                        <span class="stat-num">{{ prompt.stats.likes || 0 }}</span>
                      </button>

                      <button class="action-btn-with-stat" :class="{ 'favorited': prompt.isFavorited }" title="收藏" @click.stop="handleToggleFavorite(prompt)">
                        <Heart :size="16" :fill="prompt.isFavorited ? 'currentColor' : 'none'" />
                        <span class="stat-num">{{ prompt.stats.favorites || 0 }}</span>
                      </button>
                      <div class="action-divider"></div>
                      <CopyButton :text="prompt.content || ''" />
                      <button
                        v-if="props.showQuoteAction && !isOwnPrompt(prompt)"
                        class="like-btn"
                        title="引用到工作室"
                        @click.stop="router.push({ path: '/studio', query: { promptId: prompt.id } })"
                      >
                        <Link :size="18" />
                      </button>
                      
                      <!-- 设置按钮：只在自己的提示词且非广场模式显示 -->
                      <button
                        v-if="filter !== 'plaza' && isOwnPrompt(prompt)"
                        class="like-btn settings-btn"
                        title="设置"
                        @click.stop="showSettings($event, prompt)"
                      >
                        <MoreVertical :size="18" />
                      </button>
                    </template>
                  </div>
                </div>
                <h3 class="prompt-title">
                  <span class="title-icon" aria-hidden="true" :style="{ color: prompt.mainTag?.color || 'inherit' }">
                    <component 
                      v-if="prompt.mainTag?.icon" 
                      :is="getIconComponent(prompt.mainTag.icon)" 
                      :size="20"
                      class="lucide-icon"
                    />
                    <span v-else>{{ getPromptEmoji(prompt.tags) }}</span>
                  </span>
                  <span class="title-text">{{ prompt.title }}</span>
                </h3>
              </div>
              
              <div class="card-body">
                <p class="prompt-desc">{{ prompt.description || (prompt.content ? prompt.content.slice(0, 100) + (prompt.content.length > 100 ? '...' : '') : '暂无描述') }}</p>
                <div class="card-tags">
                  <span 
                    v-for="tag in [...new Set(prompt.tags || [])]" 
                    :key="tag" 
                    class="tag"
                    :class="getTagTone(tag)"
                  >
                    {{ tag }}
                  </span>
                </div>
              </div>
              
              <div class="card-footer">
                <div class="author-info">
                  <span class="author-avatar">
                    <!-- <img v-if="prompt.author.avatar" :src="prompt.author.avatar" alt="" class="avatar-img"> -->
                    <template v-if="true">
                      {{ prompt.author.name?.charAt(0).toUpperCase() || 'U' }}
                    </template>
                  </span>
                  <span class="author-name">{{ prompt.author.name }}</span>
                  <span class="divider">•</span>
                  <span class="prompt-date">{{ formatTimeAgo(prompt.updatedAt) }}</span>
                </div>
                
                <div class="metrics" v-if="filter !== 'plaza'">
                  <!-- MyPrompts 页面只显示分享按钮 -->
                  <template v-if="isMyPrompts && isOwnPrompt(prompt)">
                    <button 
                      class="share-btn-small" 
                      title="分享"
                      @click.stop="openShareConfirm(prompt)"
                    >
                      <Share2 :size="14" />
                      <span>分享</span>
                    </button>
                  </template>
                  <template v-else>
                    <div class="metric" title="浏览量">
                      <Eye :size="14" />
                      <span>{{ prompt.stats.views }}</span>
                    </div>
                    <div class="metric" title="点赞数">
                      <ThumbsUp :size="14" />
                      <span>{{ prompt.stats.likes || 0 }}</span>
                    </div>
                    <div class="metric" title="收藏数">
                      <Heart :size="14" />
                      <span>{{ prompt.stats.favorites || 0 }}</span>
                    </div>
                  </template>
                </div>
              </div>

              <!-- 取消分享按钮 - 只在公共分享列表显示 -->
              <div v-if="activeFilter === 'shared' && !isDeleteMode && !isShareMode" class="unshare-bar" @click.stop>
                <button class="unshare-btn" @click="handleUnshare(prompt)">
                  <span class="unshare-icon">↩</span>
                  <span>取消分享</span>
                </button>
              </div>

              <div class="card-overlay">
                <button class="use-btn">立即使用</button>
              </div>
            </div>
    </div>

    <div v-else-if="!loading" class="empty-state">
      <div class="empty-icon">
        <Search :size="34" />
      </div>
      <div class="empty-title">没有找到匹配的提示词</div>
      <div class="empty-desc">试试换个关键词，或清空搜索条件</div>
    </div>
    
    <div v-if="loading && prompts.length" class="grid-loading-overlay">
      <div class="grid-loading-indicator">
        <span class="grid-loading-dot"></span>
        <span>加载中...</span>
      </div>
    </div>
    
    <div ref="loadMoreTrigger" class="loading-state" v-show="prompts.length > 0 || loading">
      <div v-if="loading" class="loading-spinner">加载中...</div>
      <div v-else-if="prompts.length >= total" class="no-more-data">已经到底啦</div>
      <div v-else class="trigger-area" style="height: 20px; width: 100%;"></div>
    </div>

    <PromptDetailModal
      v-model:visible="showDetailModal"
      :prompt-id="selectedPromptId"
      :initial-data="selectedPromptData"
      @update="handlePromptUpdate"
    />

    <!-- 设置菜单 -->
    <div
      v-if="showSettingsMenu"
      class="settings-menu"
      :style="{ left: settingsMenuPosition.x + 'px', top: settingsMenuPosition.y + 'px' }"
      @click.stop
    >
      <div class="menu-item" @click="openTagManage(prompts.find(p => p.id === activeSettingsPromptId)!)">
        <Tag :size="16" />
        <span>管理标签</span>
      </div>
      <div class="menu-item" @click="openShareConfirm(prompts.find(p => p.id === activeSettingsPromptId)!)">
        <Share2 :size="16" />
        <span>分享</span>
      </div>
      <div class="menu-divider"></div>
      <div class="menu-item danger" @click="openDeleteConfirm(prompts.find(p => p.id === activeSettingsPromptId)!)">
        <Trash2 :size="16" />
        <span>删除</span>
      </div>
    </div>

    <!-- 标签管理弹窗 -->
    <div v-if="showTagManageModal" class="modal-overlay" @click.self="closeTagManage">
      <div class="modal-content tag-manage-modal">
        <div class="modal-header">
          <h3>管理标签</h3>
          <button class="close-btn" @click="closeTagManage">
            <X :size="20" />
          </button>
        </div>
        <div class="modal-body">
          <div class="current-tags-section">
            <h4>当前标签</h4>
            <div class="current-tags">
              <span
                v-for="tag in tagManagePrompt?.tags || []"
                :key="tag"
                class="tag-chip removable"
                :class="getTagTone(tag)"
              >
                {{ tag }}
                <button class="remove-tag-btn" @click="handleRemoveTagFromPrompt(tag)">
                  <X :size="12" />
                </button>
              </span>
              <span v-if="!tagManagePrompt?.tags?.length" class="empty-tags">暂无标签</span>
            </div>
          </div>
          <div class="add-tags-section">
            <h4>添加标签</h4>
            <div v-if="loadingTags" class="loading-tags">加载中...</div>
            <div v-else class="available-tags">
              <button
                v-for="tag in userTags.filter(t => !isTagAssociated(t.id))"
                :key="tag.id"
                class="tag-chip addable"
                @click="handleAddTagToPrompt(tag.id)"
              >
                <Plus :size="12" />
                {{ tag.tag_name }}
              </button>
              <span v-if="userTags.filter(t => !isTagAssociated(t.id)).length === 0" class="empty-tags">
                没有可添加的标签
              </span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirmModal" class="modal-overlay" @click.self="closeDeleteConfirm">
      <div class="modal-content">
        <div class="modal-header">
          <Trash2 class="warning-icon" :size="24" />
          <h3>确认删除</h3>
        </div>
        <div class="modal-body">
          <p>确定要删除提示词「<strong>{{ promptToDelete?.title }}</strong>」吗？</p>
          <p class="text-secondary">删除后提示词将无法恢复，但数据会保留在系统中。</p>
          <label class="checkbox-label">
            <input type="checkbox" v-model="deleteWithSession" />
            <span>同时删除关联的会话记录</span>
          </label>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="closeDeleteConfirm">取消</button>
          <button class="btn-danger" @click="executeDeletePrompt">确认删除</button>
        </div>
      </div>
    </div>

    <!-- 分享确认弹窗 -->
    <div v-if="showShareConfirmModal" class="modal-overlay" @click.self="closeShareConfirm">
      <div class="modal-content share-modal">
        <div class="modal-header">
          <Share2 class="primary-icon" :size="24" />
          <h3>分享提示词</h3>
        </div>
        <div class="modal-body">
          <p>分享提示词「<strong>{{ promptToShare?.title }}</strong>」到：</p>
          
          <!-- 分享范围选择 -->
          <div class="share-scope-section">
            <div class="scope-options">
              <label class="scope-option" :class="{ active: shareScope === 'all' }">
                <input type="radio" v-model="shareScope" value="all" />
                <div class="scope-content">
                  <span class="scope-title">全部部门</span>
                  <span class="scope-desc">所有用户都可以在提示词广场看到</span>
                </div>
              </label>
              <label class="scope-option" :class="{ active: shareScope === 'department' }">
                <input type="radio" v-model="shareScope" value="department" />
                <div class="scope-content">
                  <span class="scope-title">指定部门</span>
                  <span class="scope-desc">仅分享给选定部门的用户</span>
                </div>
              </label>
            </div>
            
            <!-- 部门选择器 -->
            <div v-if="shareScope === 'department'" class="department-select-wrapper">
              <div v-if="loadingDepartments" class="loading-departments">加载部门中...</div>
              <div v-else-if="departments.length === 0" class="empty-departments">暂无可用部门</div>
              <div v-else class="department-list">
                <label 
                  v-for="dept in departments" 
                  :key="dept.department_id || dept.id" 
                  class="department-option"
                  :class="{ active: selectedDepartment === (dept.department_id || dept.id) }"
                >
                  <input 
                    type="radio" 
                    v-model="selectedDepartment" 
                    :value="dept.department_id || dept.id" 
                  />
                  <span class="dept-name">{{ dept.department_name || dept.name }}</span>
                </label>
              </div>
            </div>
          </div>
        </div>
        <div class="modal-footer">
          <button class="btn-secondary" @click="closeShareConfirm">取消</button>
          <button 
            class="btn-primary" 
            @click="executeSharePrompt"
            :disabled="shareScope === 'department' && !selectedDepartment"
          >
            确认分享
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.prompt-list-container {
  display: flex;
  flex-direction: column;
  gap: 24px;
  /* height: 100%; */ /* Removed for standard scrolling */
  min-height: 0;
  /* padding-bottom: 40px; */ /* Removed to prevent overflow in fixed height layout */
  position: relative;
}

/* Toolbar */
.toolbar {
  padding: 16px;
  border-radius: var(--radius-xl);
  display: flex;
  flex-direction: column;
  gap: 16px;
  background: var(--bg-surface);
  border: 1px solid rgba(0,0,0,0.02);
  box-shadow: var(--shadow-sm);
}

.search-section {
  width: 100%;
}

.search-input-wrapper {
  position: relative;
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 16px;
  top: 50%;
  transform: translateY(-50%);
  color: var(--text-tertiary);
}

.main-search-input {
  width: 100%;
  padding: 12px 88px 12px 48px;
  border: none;
  border-radius: 24px; /* Pill Shape */
  font-size: 15px;
  background: var(--bg-secondary);
  color: var(--text-primary);
  transition: all var(--transition-fast);
}

.main-search-input:focus {
  outline: none;
  background: var(--bg-primary);
}

.search-shortcut {
  position: absolute;
  right: 14px;
  top: 50%;
  transform: translateY(-50%);
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-tertiary);
  font-size: 12px;
  pointer-events: none;
}

.search-shortcut kbd {
  font: inherit;
  padding: 2px 8px;
  border-radius: 8px;
  border: 1px solid rgba(0,0,0,0.05);
  background: var(--bg-surface);
  box-shadow: 0 1px 0 rgba(0,0,0,0.05);
}

.kbd-plus {
  opacity: 0.7;
}

@media (max-width: 768px) {
  .search-shortcut {
    display: none;
  }

  .main-search-input {
    padding-right: 16px;
  }
}

.filter-section {
  display: flex;
  justify-content: space-between;
  align-items: center;
  flex-wrap: wrap;
  gap: 16px;
}

.filter-tabs {
  display: flex;
  background: var(--bg-secondary);
  padding: 4px;
  border-radius: 24px;
  gap: 4px;
}

.filter-tab {
  padding: 6px 16px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  font-weight: 500;
  font-size: 14px;
  border-radius: 20px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.filter-tab:hover {
  color: var(--text-primary);
  background: rgba(0,0,0,0.03);
}

.filter-tab.active {
  background: var(--bg-surface);
  color: var(--primary);
  box-shadow: var(--shadow-sm);
  font-weight: 600;
}

.sort-selector {
  display: flex;
  align-items: center;
  gap: 8px;
}

.sort-label {
  font-size: 13px;
  color: var(--text-secondary);
}

.select-wrapper {
  position: relative;
  display: flex;
  align-items: center;
}

.sort-select {
  border: none;
  border-radius: 20px;
  padding: 6px 32px 6px 12px;
  font-size: 13px;
  color: var(--text-primary);
  background: var(--bg-secondary);
  cursor: pointer;
  appearance: none;
  transition: all var(--transition-fast);
}

.sort-select:hover {
  background: rgba(0,0,0,0.05);
}

.select-icon {
  position: absolute;
  right: 10px;
  color: var(--text-tertiary);
  pointer-events: none;
}

.sort-select:focus {
  outline: none;
  background: var(--bg-primary);
}

/* Stats */
.stats-bar {
  display: flex;
  padding: 0 8px;
}

.stat-item {
  display: flex;
  align-items: center;
  gap: 6px;
  color: var(--text-secondary);
  font-size: 13px;
}

/* Grid */
.prompt-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: var(--layout-gap);
}

.prompt-card {
  border-radius: var(--radius-xl);
  padding: 24px;
  display: flex;
  flex-direction: column;
  transition: all var(--transition-normal);
  position: relative;
  overflow: hidden;
  height: 240px;
  border: 1px solid rgba(0,0,0,0.02);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  cursor: pointer;
  will-change: transform;
}

.prompt-card:hover {
  transform: translateY(-4px);
  box-shadow: var(--shadow-card);
}

.card-loading-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(255, 255, 255, 0.6);
  backdrop-filter: blur(2px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 20;
  border-radius: inherit;
}

.spinner {
  width: 24px;
  height: 24px;
  border: 2px solid var(--primary-light);
  border-top-color: var(--primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* Own Prompt Badge & Effect */
.prompt-card.is-own {
  border: 1px solid var(--primary-light);
  background: linear-gradient(to bottom right, var(--bg-surface), rgba(var(--primary-rgb), 0.02));
}

.own-badge {
  position: absolute;
  top: 0;
  left: 0;
  padding: 4px 10px 4px 8px;
  background: var(--primary);
  color: white;
  font-size: 11px;
  font-weight: 600;
  border-bottom-right-radius: 12px;
  display: flex;
  align-items: center;
  gap: 4px;
  z-index: 10;
  box-shadow: 2px 2px 8px rgba(var(--primary-rgb), 0.2);
  letter-spacing: 0.5px;
}

.own-badge span {
  line-height: 1;
}

/* Drag and Drop Styles */
.prompt-card.drag-over {
  border: 2px dashed var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
  transform: scale(1.02);
  box-shadow: 0 0 20px rgba(var(--primary-rgb), 0.3);
}

.prompt-card.drag-over::after {
  content: '放置添加标签';
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  background: var(--primary);
  color: white;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 14px;
  font-weight: 500;
  z-index: 10;
  pointer-events: none;
  animation: fadeIn 0.2s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
    transform: translate(-50%, -50%) scale(0.9);
  }
  to {
    opacity: 1;
    transform: translate(-50%, -50%) scale(1);
  }
}

/* Delete Mode Styles */
.prompt-grid.delete-mode .prompt-card {
  position: relative;
  cursor: pointer;
}

.prompt-card.delete-mode {
  border: 2px solid transparent;
  transition: all 0.2s;
}

.prompt-card.delete-mode:hover {
  border-color: var(--primary);
}

.prompt-card.delete-mode.selected {
  border-color: var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
}

.selection-indicator {
  position: absolute;
  top: 12px;
  right: 12px;
  z-index: 10;
  width: 36px;
  height: 36px;
  border-radius: 999px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(255, 255, 255, 0.9);
  border: 1px solid rgba(0, 0, 0, 0.06);
  box-shadow: var(--shadow-sm);
  transition: all 0.2s ease;
  cursor: pointer;
}

.selection-indicator:hover {
  transform: scale(1.05);
}

.selection-indicator.checked {
  background: rgba(var(--primary-rgb), 0.12);
  border-color: rgba(var(--primary-rgb), 0.35);
}

.selection-indicator .checked {
  color: var(--primary);
}

.selection-indicator .unchecked {
  color: var(--text-tertiary);
  opacity: 0.5;
}

.card-header {
  margin-bottom: 12px;
}

.header-top {
  display: flex;
  justify-content: flex-end;
  align-items: flex-start;
  margin-bottom: 12px;
}

.actions {
  display: flex;
  gap: 8px;
}

.like-btn {
  width: 32px;
  height: 32px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: var(--text-tertiary);
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.like-btn:hover {
  background: rgba(0,0,0,0.05);
  color: #ef4444;
}

.like-btn.liked {
  color: #f59e0b;
}

.like-btn.favorited {
  color: #ef4444;
}

.card-body {
  flex: 1;
  margin-bottom: 16px;
  cursor: pointer;
  display: flex;
  flex-direction: column;
  min-height: 0;
}

.prompt-title {
  font-size: 17px;
  font-weight: 600;
  color: var(--text-primary);
  margin-bottom: 0;
  line-height: 1.4;
  display: flex;
  align-items: center;
  gap: 8px;
}

.title-icon {
  width: 20px;
  height: 20px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  font-size: 16px;
  flex-shrink: 0;
}

.title-text {
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.prompt-desc {
  font-size: 14px;
  color: var(--text-secondary);
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  margin-top: 8px;
}

.prompt-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
}

.tag {
  font-size: 11px;
  padding: 2px 10px;
  border-radius: 100px;
  font-weight: 500;
}

.tag--blue {
  color: #1a73e8;
  background: #e8f0fe;
}

.tag--purple {
  color: #7030a0;
  background: #f3e5f5;
}

.tag--amber {
  color: #e67c73;
  background: #feefe3;
}

.tag--emerald {
  color: #0f9d58;
  background: #e6f4ea;
}

.tag--gray {
  color: var(--text-secondary);
  background: var(--bg-secondary);
}

.tag-more {
  color: var(--text-tertiary);
  background: var(--bg-secondary);
  font-size: 10px;
  padding: 2px 6px;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 16px;
  border-top: 1px solid var(--bg-primary);
  font-size: 12px;
  color: var(--text-tertiary);
  margin-top: auto;
  flex-shrink: 0;
}

.author-info {
  display: flex;
  align-items: center;
  gap: 6px;
}

.author-avatar {
  width: 20px;
  height: 20px;
  border-radius: 50%;
  background: var(--primary);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 10px;
  font-weight: 600;
  overflow: hidden;
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.divider {
  color: var(--bg-primary);
}

.metrics {
  display: flex;
  gap: 12px;
  align-items: center;
}

.metric {
  display: flex;
  align-items: center;
  gap: 4px;
}

.share-btn-small {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 10px;
  border-radius: 6px;
  border: 1px solid var(--primary);
  background: transparent;
  color: var(--primary);
  font-size: 12px;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.share-btn-small:hover {
  background: var(--primary);
  color: white;
}

.action-btn-with-stat {
  display: flex;
  align-items: center;
  gap: 4px;
  padding: 4px 8px;
  border-radius: 6px;
  border: none;
  background: transparent;
  color: var(--text-tertiary);
  cursor: pointer;
  transition: all var(--transition-fast);
}

.action-btn-with-stat:hover {
  background: rgba(0,0,0,0.05);
  color: var(--text-primary);
}

.action-btn-with-stat.liked {
  color: #f59e0b;
}

.action-btn-with-stat.favorited {
  color: #ef4444;
}

.action-btn-with-stat.no-interact {
  cursor: default;
  pointer-events: none;
}

.action-btn-with-stat.no-interact:hover {
  background: transparent;
}

.stat-num {
  font-size: 12px;
  font-weight: 500;
}

.action-divider {
  width: 1px;
  height: 16px;
  background: var(--border-color, rgba(0,0,0,0.06));
  margin: 0 4px;
}

/* Unshare Bar */
.unshare-bar {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  padding: 8px 16px;
  background: linear-gradient(to top, rgba(239, 68, 68, 0.95), rgba(239, 68, 68, 0.85));
  border-top: 1px solid rgba(255, 255, 255, 0.1);
  display: flex;
  justify-content: center;
  align-items: center;
  transform: translateY(100%);
  transition: transform 0.25s ease;
  z-index: 5;
}

.prompt-card:hover .unshare-bar {
  transform: translateY(0);
}

.unshare-btn {
  display: flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: white;
  padding: 6px 14px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
}

.unshare-btn:hover {
  background: rgba(255, 255, 255, 0.15);
  border-color: rgba(255, 255, 255, 0.5);
}

.unshare-icon {
  font-size: 14px;
}

/* Overlay Action */
.card-overlay {
  display: none;
}

.use-btn {
  background: var(--primary-600);
  color: white;
  border: none;
  padding: 8px 20px;
  border-radius: 100px;
  font-weight: 600;
  font-size: 14px;
  transform: translateY(10px);
  transition: all var(--transition-normal);
  box-shadow: var(--shadow-lg);
  cursor: pointer;
  pointer-events: auto;
}

/* Empty */
.empty-state {
  border-radius: var(--radius-xl);
  border: 1px solid var(--border-subtle);
  background: var(--bg-surface);
  box-shadow: var(--shadow-sm);
  padding: 44px 20px;
  text-align: center;
}

.empty-icon {
  width: 56px;
  height: 56px;
  margin: 0 auto 12px;
  border-radius: 16px;
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--gray-500);
  background: var(--gray-50);
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.empty-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--gray-800);
}

.empty-desc {
  margin-top: 6px;
  font-size: 13px;
  color: var(--gray-500);
}

.grid-loading-overlay {
  position: absolute;
  inset: 0;
  background: rgba(255, 255, 255, 0.6);
  backdrop-filter: blur(1px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 5;
}

.grid-loading-indicator {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 14px;
  border-radius: 999px;
  background: var(--bg-surface);
  color: var(--text-secondary);
  font-size: 13px;
  box-shadow: var(--shadow-sm);
  border: 1px solid var(--border-subtle);
}

.grid-loading-dot {
  width: 6px;
  height: 6px;
  border-radius: 999px;
  background: var(--primary);
  animation: dotPulse 1s ease-in-out infinite;
}

@keyframes dotPulse {
  0%, 100% { opacity: 0.3; transform: scale(0.9); }
  50% { opacity: 1; transform: scale(1); }
}

@keyframes fadeUp {
  from {
    opacity: 0;
    transform: translateY(8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.avatar-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 50%;
}

.liked {
  color: #ef4444;
  background: #fef2f2;
  border-color: #fee2e2;
}

.loading-state {
  display: flex;
  justify-content: center;
  align-items: center;
  padding: 40px;
  color: var(--gray-500);
  font-size: 14px;
}

/* Virtual Scroll */
.virtual-scroll-wrapper {
  flex: 1;
  width: 100%;
}

.scroller {
  height: 100%;
}

.prompt-row {
  display: grid;
  gap: 16px;
  width: 100%;
}

/* Settings Menu */
.settings-menu {
  position: fixed;
  background: var(--bg-surface);
  border-radius: 12px;
  box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
  border: 1px solid var(--border-subtle);
  padding: 8px;
  z-index: 1000;
  min-width: 160px;
  animation: menuFadeIn 0.15s ease;
}

@keyframes menuFadeIn {
  from {
    opacity: 0;
    transform: translateY(-8px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.menu-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  font-size: 14px;
  color: var(--text-primary);
  transition: all 0.2s;
}

.menu-item:hover {
  background: var(--bg-secondary);
}

.menu-item.danger {
  color: #ef4444;
}

.menu-item.danger:hover {
  background: #fef2f2;
}

.menu-divider {
  height: 1px;
  background: var(--border-subtle);
  margin: 6px 0;
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
  border-radius: 16px;
  padding: 24px;
  min-width: 400px;
  max-width: 90vw;
  max-height: 80vh;
  overflow-y: auto;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.2);
}

.modal-content.tag-manage-modal {
  min-width: 500px;
}

.modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 20px;
}

.modal-header h3 {
  font-size: 18px;
  font-weight: 600;
  color: var(--text-primary);
}

.close-btn {
  width: 32px;
  height: 32px;
  border-radius: 8px;
  border: none;
  background: transparent;
  color: var(--text-secondary);
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s;
}

.close-btn:hover {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.modal-body {
  margin-bottom: 24px;
}

.modal-body p {
  margin-bottom: 12px;
  color: var(--text-primary);
}

.modal-body .text-secondary {
  color: var(--text-secondary);
  font-size: 14px;
}

.modal-footer {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
}

.btn-secondary, .btn-danger, .btn-primary {
  padding: 10px 20px;
  border-radius: 8px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
  font-size: 14px;
}

.btn-secondary {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.btn-secondary:hover {
  background: var(--bg-tertiary);
}

.btn-danger {
  background: #ef4444;
  color: white;
}

.btn-danger:hover {
  background: #dc2626;
}

.btn-primary {
  background: var(--primary);
  color: white;
}

.btn-primary:hover {
  background: var(--primary-hover);
}

.warning-icon {
  color: #f59e0b;
}

.primary-icon {
  color: var(--primary);
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

/* Tag Manage Modal */
.current-tags-section,
.add-tags-section {
  margin-bottom: 24px;
}

.current-tags-section h4,
.add-tags-section h4 {
  font-size: 14px;
  font-weight: 600;
  color: var(--text-secondary);
  margin-bottom: 12px;
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.current-tags,
.available-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  min-height: 40px;
}

.tag-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 20px;
  font-size: 13px;
  font-weight: 500;
  transition: all 0.2s;
}

.tag-chip.removable {
  background: var(--bg-secondary);
  color: var(--text-primary);
}

.tag-chip.removable:hover {
  background: var(--bg-tertiary);
}

.tag-chip.addable {
  background: transparent;
  border: 1px dashed var(--border-color);
  color: var(--text-secondary);
  cursor: pointer;
}

.tag-chip.addable:hover {
  border-color: var(--primary);
  color: var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
}

.remove-tag-btn {
  width: 18px;
  height: 18px;
  border-radius: 50%;
  border: none;
  background: transparent;
  color: inherit;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  opacity: 0.6;
  transition: all 0.2s;
}

.remove-tag-btn:hover {
  opacity: 1;
  background: rgba(0, 0, 0, 0.1);
}

.empty-tags {
  color: var(--text-tertiary);
  font-size: 14px;
  font-style: italic;
}

.loading-tags {
  color: var(--text-secondary);
  font-size: 14px;
  padding: 20px;
  text-align: center;
}

.settings-btn {
  opacity: 1;
  color: var(--text-secondary);
}

.settings-btn:hover {
  color: var(--primary);
  background: var(--bg-secondary);
}

/* Share Modal Styles */
.share-modal {
  max-width: 480px;
  width: 90vw;
}

.share-scope-section {
  margin-top: 20px;
}

.scope-options {
  display: flex;
  flex-direction: column;
  gap: 12px;
  margin-bottom: 20px;
}

.scope-option {
  display: flex;
  align-items: flex-start;
  gap: 12px;
  padding: 16px;
  border-radius: 12px;
  border: 2px solid var(--border-subtle);
  cursor: pointer;
  transition: all 0.2s;
  background: var(--bg-primary);
}

.scope-option:hover {
  border-color: var(--primary-light);
}

.scope-option.active {
  border-color: var(--primary);
  background: rgba(var(--primary-rgb), 0.05);
}

.scope-option input[type="radio"] {
  margin-top: 2px;
  width: 18px;
  height: 18px;
  cursor: pointer;
}

.scope-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.scope-title {
  font-size: 15px;
  font-weight: 600;
  color: var(--text-primary);
}

.scope-desc {
  font-size: 13px;
  color: var(--text-secondary);
}

.department-select-wrapper {
  padding: 16px;
  background: var(--bg-secondary);
  border-radius: 12px;
  max-height: 200px;
  overflow-y: auto;
}

.loading-departments,
.empty-departments {
  padding: 20px;
  text-align: center;
  color: var(--text-secondary);
  font-size: 14px;
}

.department-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.department-option {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  background: var(--bg-primary);
  border: 1px solid transparent;
}

.department-option:hover {
  border-color: var(--primary-light);
}

.department-option.active {
  border-color: var(--primary);
  background: rgba(var(--primary-rgb), 0.08);
}

.department-option input[type="radio"] {
  width: 16px;
  height: 16px;
  cursor: pointer;
}

.dept-name {
  font-size: 14px;
  color: var(--text-primary);
  font-family: monospace;
  white-space: pre;
}
</style>

/**
 * Prompt Studio 保存提示词 API 模块
 * 对接 Python 后端 (/api/python/*)
 * 
 * 注意：Python后端路由挂载在 /api/ai 前缀下
 * Vite代理会将 /api/python 重写为 /api
 * 所以请求路径需要加上 /ai 前缀
 */
import request from '@/utils/request'

// ==================== 类型定义 ====================

export interface SavePromptRequest {
  /** 关联的会话ID */
  session_id: number
  /** 提示词标题 */
  title: string
  /** 提示词内容，为空时根据source_type获取 */
  content?: string
  /** 保存来源: prompt-编辑器内容, reply-AI回复 */
  source_type: 'prompt' | 'reply'
  /** 当source_type=reply时，选中的消息ID */
  message_id?: number
  /** 可见范围: private-私有, plaza-公开 */
  visibility?: 'private' | 'plaza'
  /** 公开时的部门ID，visibility=plaza时必填 */
  department_id?: number
  /** 关联的标签ID列表 */
  tag_ids?: number[]
  /** 保存到的目录ID */
  directory_id?: number
  /** 图标代码 */
  icon_code?: string
  /** 提示词描述 */
  description?: string
  /** 用户输入示例 */
  user_input_example?: string
  /** 变量配置JSON */
  variables_json?: Record<string, any>
  /** 模型参数配置JSON */
  model_config_json?: Record<string, any>
  /** 保存后是否收敛会话 */
  finalize_session?: boolean
  /** 如提供则更新现有提示词，否则新建 */
  prompt_id?: number
}

export interface SavePromptResponse {
  code: number
  message: string
  data: {
    prompt_id: number
    session_id: number
    session_status: number
    final_content: string
    is_update: boolean
  }
}

export interface CreateTagRequest {
  /** 标签名称 */
  tag_name: string
  /** 父标签ID，0表示根标签 */
  parent_id?: number
  /** 图标代码 */
  icon_code?: string
  /** 标签颜色 */
  color?: string
}

export interface TagNode {
  id: number
  tag_name: string
  type: number
  parent_id: number
  icon_code?: string
  color?: string
  department_id?: number
  children: TagNode[]
}

export interface DepartmentNode {
  id: number
  name: string
  parent_id: number
  department_id?: number
  children: DepartmentNode[]
}

export interface SessionSaveInfo {
  session: {
    id: number
    user_id: number
    title: string
    status: number
    origin_prompt_id?: number
    final_content?: string
  }
  prompt?: {
    id: number
    title: string
    content: string
    user_id: number
    department_id?: number
    status: number
  }
  messages: Array<{
    id: number
    role: string
    content: string
    create_time: string
  }>
  can_continue_chat: boolean
}

export interface PromptDetail {
  id: number
  uuid: string
  title: string
  content: string
  description?: string
  user_input_example?: string
  variables_json?: Record<string, any>
  model_config_json?: Record<string, any>
  user_id: number
  user_name: string
  department_id?: number
  status: number
  icon_code?: string
  view_count: number
  like_count: number
  favorite_count: number
  create_time: string
  update_time: string
  tags: Array<{
    id: number
    tag_name: string
    type: number
    icon_code?: string
    color?: string
  }>
}

// ==================== API 方法 ====================
// Python后端挂载在 /api/ai 前缀下
// Vite代理: /api/python/* -> /api/*
// 所以请求路径需要是: /python/ai/prompts/*

/**
 * 从 Prompt Studio 保存提示词
 * 对接 Python 后端
 */
export function savePromptFromStudio(data: SavePromptRequest): Promise<SavePromptResponse['data']> {
  return request<SavePromptResponse, SavePromptResponse['data']>({
    url: '/python/ai/prompts/save_from_studio',
    method: 'post',
    data
  })
}

/**
 * 创建个人标签
 */
export function createPersonalTag(data: CreateTagRequest): Promise<{ tag_id: number; tag_name: string }> {
  return request<any, { tag_id: number; tag_name: string }>({
    url: '/python/ai/prompts/tags/personal',
    method: 'post',
    data
  })
}

/**
 * 获取标签树（系统标签 + 个人标签 + 公开标签）
 * @param include_personal 是否包含当前用户创建的个人标签
 * @param include_all_public 是否包含所有已关联部门的公开标签（用于提示词广场）
 */
export function getPythonTagsTree(
  include_personal = true,
  include_all_public = false
): Promise<{ system_tags: TagNode[]; personal_tags: TagNode[]; public_tags: TagNode[] }> {
  return request<any, { system_tags: TagNode[]; personal_tags: TagNode[]; public_tags: TagNode[] }>({
    url: '/python/ai/prompts/tags/tree',
    method: 'get',
    params: { include_personal, include_all_public }
  })
}

/**
 * 获取部门树
 */
export function getPythonDepartmentsTree(): Promise<DepartmentNode[]> {
  return request<any, DepartmentNode[]>({
    url: '/python/ai/prompts/departments/tree',
    method: 'get'
  })
}

/**
 * 获取会话保存信息
 */
export function getSessionSaveInfo(session_id: number): Promise<SessionSaveInfo> {
  return request<any, SessionSaveInfo>({
    url: `/python/ai/prompts/sessions/${session_id}/save_info`,
    method: 'get'
  })
}

/**
 * 获取提示词详情
 */
export function getPythonPromptDetail(prompt_id: number): Promise<PromptDetail> {
  return request<any, PromptDetail>({
    url: `/python/ai/prompts/${prompt_id}/detail`,
    method: 'get'
  })
}

/**
 * 获取提示词关联的会话
 * 用于点击提示词卡片时，找到对应的会话并跳转
 */
export function getPromptSession(prompt_id: number): Promise<{
  code: number
  message: string
  data?: {
    session_id: number
    title: string
    status: number
    create_time?: string
    update_time?: string
  }
}> {
  return request<any, {
    code: number
    message: string
    data?: {
      session_id: number
      title: string
      status: number
      create_time?: string
      update_time?: string
    }
  }>({
    url: `/python/ai/prompts/${prompt_id}/session`,
    method: 'get'
  })
}

/**
 * 删除提示词
 * @param prompt_id 提示词ID
 * @param delete_session 是否同步删除关联的会话记录
 */
export function deletePrompt(prompt_id: number, delete_session = false): Promise<{ code: number; message: string; data?: { prompt_id: number; deleted_sessions: number } }> {
  return request<any, { code: number; message: string; data?: { prompt_id: number; deleted_sessions: number } }>({
    url: `/python/ai/prompts/${prompt_id}`,
    method: 'delete',
    params: { delete_session }
  })
}

/**
 * 删除个人标签
 * @param tag_id 标签ID
 * @param delete_prompts 是否同步删除关联的提示词
 */
export function deletePersonalTag(tag_id: number, delete_prompts = false): Promise<{ code: number; message: string; data?: { tag_id: number; deleted_prompts: number } }> {
  return request<any, { code: number; message: string; data?: { tag_id: number; deleted_prompts: number } }>({
    url: `/python/ai/prompts/tags/${tag_id}`,
    method: 'delete',
    params: { delete_prompts }
  })
}

/**
 * 删除自己创建的公共标签
 * @param tag_id 标签ID
 * @param delete_prompts 是否同步删除关联的提示词
 */
export function deletePublicTag(tag_id: number, delete_prompts = false): Promise<{ code: number; message: string; data?: { tag_id: number; deleted_prompts: number } }> {
  return request<any, { code: number; message: string; data?: { tag_id: number; deleted_prompts: number } }>({
    url: `/python/ai/prompts/tags/${tag_id}/public`,
    method: 'delete',
    params: { delete_prompts }
  })
}

/**
 * 更新个人标签的关联部门
 * 用途：当用户创建标签后保存公开提示词时，将标签关联到对应部门
 * @param tag_id 标签ID
 * @param department_id 部门ID
 */
export function updateTagDepartment(tag_id: number, department_id: number): Promise<{ code: number; message: string; data?: { tag_id: number; department_id: number } }> {
  return request<any, { code: number; message: string; data?: { tag_id: number; department_id: number } }>({
    url: `/python/ai/prompts/tags/${tag_id}/department`,
    method: 'put',
    data: { department_id }
  })
}

/**
 * 为提示词添加标签（拖拽功能）
 * @param prompt_id 提示词ID
 * @param tag_id 标签ID
 */
export function addTagToPrompt(prompt_id: number, tag_id: number): Promise<{ code: number; message: string; data?: { prompt_id: number; tag_id: number; tag_name: string } }> {
  return request<any, { code: number; message: string; data?: { prompt_id: number; tag_id: number; tag_name: string } }>({
    url: `/python/ai/prompts/${prompt_id}/tags`,
    method: 'post',
    data: { tag_id }
  })
}

/**
 * 从提示词移除标签
 * @param prompt_id 提示词ID
 * @param tag_id 标签ID
 */
export function removeTagFromPrompt(prompt_id: number, tag_id: number): Promise<{ code: number; message: string; data?: { prompt_id: number; tag_id: number } }> {
  return request<any, { code: number; message: string; data?: { prompt_id: number; tag_id: number } }>({
    url: `/python/ai/prompts/${prompt_id}/tags/${tag_id}`,
    method: 'delete'
  })
}

/**
 * 测试Python后端路由
 */
export function testPythonPromptRouter(): Promise<{ code: number; message: string }> {
  return request<any, { code: number; message: string }>({
    url: '/python/ai/prompts/test',
    method: 'get'
  })
}

// ==================== 个人中心 API ====================

export interface UserStats {
  total_prompts: number
  favorite_count: number
  like_count: number
  share_count: number
  view_count: number
  copy_count: number
}

export interface ActivityItem {
  id: number
  type: string
  text: string
  highlight: string
  time: string
  icon: string
}

export interface UserPromptItem {
  id: number
  title: string
  like_count: number
  favorite_count: number
  copy_count: number
  view_count: number
  create_time: string
  update_time: string
  status: number
  is_template: number
}

export interface UserPromptsResponse {
  list: UserPromptItem[]
  total: number
  page: number
  page_size: number
  total_pages: number
}

/**
 * 获取用户统计数据
 */
export function getUserStats(): Promise<UserStats> {
  return request<any, UserStats>({
    url: '/python/ai/prompts/user/stats',
    method: 'get'
  })
}

/**
 * 获取用户最近活动记录
 * @param limit 返回条数限制
 */
export function getUserActivities(limit = 10): Promise<ActivityItem[]> {
  return request<any, ActivityItem[]>({
    url: '/python/ai/prompts/user/activities',
    method: 'get',
    params: { limit }
  })
}

/**
 * 获取用户创建的提示词列表
 * @param page 页码
 * @param page_size 每页条数
 * @param status 状态筛选
 */
export function getUserPrompts(page = 1, page_size = 10, status?: number): Promise<UserPromptsResponse> {
  return request<any, UserPromptsResponse>({
    url: '/python/ai/prompts/user/prompts',
    method: 'get',
    params: { page, page_size, status }
  })
}

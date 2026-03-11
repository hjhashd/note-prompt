import request from '@/utils/request'
import type { PromptListParams, PromptListResponse, PromptItem, TagItem } from '@/types/prompt'

export function getPrompts(params: PromptListParams) {
  return request<any, PromptListResponse>({
    url: '/java/v1/prompts',
    method: 'get',
    params
  })
}

// Helper to map backend Tag structure to frontend TagItem
const mapTag = (tag: any): TagItem => ({
  id: tag.id,
  name: tag.tagName || tag.name, // Handle backend 'tagName' vs frontend 'name'
  parentId: tag.parentId,
  sortOrder: tag.sortOrder || 0,
  children: tag.children?.map(mapTag) || [],
  count: tag.count,
  icon: tag.icon,
  departmentId: tag.departmentId ?? tag.department_id // Support both camelCase and snake_case
})

export function getTagsTree() {
  return request<any, any[]>({
    url: '/java/v1/tags/tree',
    method: 'get'
  }).then(data => data.map(mapTag))
}

export function getUserTagsTree() {
  return request<any, any[]>({
    url: '/java/v1/tags/user/tree',
    method: 'get'
  }).then(data => data.map(mapTag))
}

export function getPromptDetail(id: number) {
  return request<any, PromptItem>({
    url: `/java/v1/prompts/${id}`,
    method: 'get'
  })
}

export function toggleFavorite(id: number) {
  return request<any, boolean>({
    url: `/java/v1/prompts/${id}/favorite`,
    method: 'post'
  })
}

export function toggleLike(id: number) {
  return request<any, boolean>({
    url: `/java/v1/prompts/${id}/like`,
    method: 'post'
  })
}

export function batchSharePrompts(ids: number[], departmentId?: number) {
  return request<any, void>({
    url: '/java/v1/prompts/batch-share',
    method: 'post',
    data: {
      ids,
      departmentId
    }
  })
}

export function batchUnsharePrompts(ids: number[]) {
  return request<any, void>({
    url: '/java/v1/prompts/batch-unshare',
    method: 'post',
    data: ids
  })
}

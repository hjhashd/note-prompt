import request from '@/utils/request'
import type { PromptListParams, PromptListResponse, PromptItem, TagItem } from '@/types/prompt'

export function getPrompts(params: PromptListParams) {
  return request<any, PromptListResponse>({
    url: '/java/v1/prompts',
    method: 'get',
    params
  })
}

export function getTagsTree() {
  return request<any, TagItem[]>({
    url: '/java/v1/tags/tree',
    method: 'get'
  })
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

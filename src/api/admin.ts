import request from '@/utils/request'

export interface SystemStats {
  total_users: number
  total_prompts: number
  total_likes: number
  total_uses: number
  total_favorites: number
  total_shares: number
  total_views: number
  active_users_today: number
  new_prompts_today: number
}

export interface TopUser {
  id: number
  name: string
  email?: string
  score: number
  rank: number
  prompt_count: number
  like_count: number
}

export interface TopPrompt {
  id: number
  title: string
  author: string
  score: number
  rank: number
  like_count: number
  view_count: number
  copy_count: number
}

export interface UserListItem {
  id: number
  name: string
  email?: string
  role: string
  status: string
  join_date: string
  prompt_count: number
  department_id?: number
  department_name?: string
}

export interface UserListResponse {
  list: UserListItem[]
  total: number
  page: number
  page_size: number
  total_pages: number
}

export interface UserDetail {
  id: number
  name: string
  department_id?: number
  department_name?: string
  prompt_count: number
  first_create_time: string
  last_create_time: string
  total_likes: number
  total_views: number
  total_copies: number
  total_favorites: number
}

export interface DailyStat {
  date: string
  count: number
}

export interface ActionStats {
  like: number
  favorite: number
  share: number
  copy: number
}

export interface InteractionStats {
  daily: DailyStat[]
  by_action: ActionStats
}

export function getSystemStats() {
  return request<any, SystemStats>({
    url: '/python/admin/stats',
    method: 'get'
  })
}

export function getTopUsers(limit: number = 10) {
  return request<any, TopUser[]>({
    url: '/python/admin/top-users',
    method: 'get',
    params: { limit }
  })
}

export function getTopPrompts(limit: number = 10) {
  return request<any, TopPrompt[]>({
    url: '/python/admin/top-prompts',
    method: 'get',
    params: { limit }
  })
}

export function getUsersList(params: {
  page?: number
  page_size?: number
  status?: string
  keyword?: string
}) {
  return request<any, UserListResponse>({
    url: '/python/admin/users',
    method: 'get',
    params
  })
}

export function getUserDetail(userId: number) {
  return request<any, UserDetail>({
    url: `/python/admin/user/${userId}`,
    method: 'get'
  })
}

export function getInteractionStats(days: number = 7) {
  return request<any, InteractionStats>({
    url: '/python/admin/interaction-stats',
    method: 'get',
    params: { days }
  })
}

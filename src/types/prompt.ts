export interface PromptAuthor {
  id?: number
  name: string
  avatar?: string
}

export interface PromptStats {
  views: number
  likes: number
  favorites?: number
}

export interface PromptItem {
  id: number
  uuid?: string
  title: string
  description?: string // 改为可选
  content?: string
  tags: string[]
  author: PromptAuthor
  stats: PromptStats
  updatedAt: string
  createdAt?: string
  isLiked: boolean
  isFavorited?: boolean
}

export interface PromptListParams {
  page?: number
  pageSize?: number
  keyword?: string
  filter?: 'all' | 'my' | 'favorites' | 'shared'
  sort?: 'updatedAt' | 'createdAt' | 'views' | 'likes'
  order?: 'asc' | 'desc'
  tagId?: number | null
}

export interface TagItem {
  id: number
  name: string
  parentId: number | null
  sortOrder: number
  description?: string
  children?: TagItem[]
  count?: number // Optional count if backend provides it, or calculated
  icon?: string // Optional icon path
}

export interface PromptListResponse {
  total: number
  page: number
  pageSize: number
  list: PromptItem[]
}

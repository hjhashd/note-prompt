import request from '@/utils/request'

export interface UserInfo {
  id: number
  username: string
  roles: string[]
  department_id?: number
}

export interface LoginResponse {
  token: string
  userInfo: UserInfo
}

export function login(data: any): Promise<LoginResponse> {
  return request({
    url: '/java/auth/login',
    method: 'post',
    data
  }) as any
}

export interface RegisterData {
  username: string
  password: string
}

export interface RegisterResponse {
  success: boolean
  message: string
  user?: UserInfo
}

export function register(data: RegisterData): Promise<RegisterResponse> {
  return request({
    url: '/python/auth/register',
    method: 'post',
    data
  }) as any
}

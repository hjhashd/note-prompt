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

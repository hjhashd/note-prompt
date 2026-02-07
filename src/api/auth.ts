import request from '@/utils/request'

export interface LoginResponse {
  token: string
  userInfo: any
}

export function login(data: any): Promise<LoginResponse> {
  return request({
    url: '/java/auth/login', // 路由到 Java 后端: /api/java/auth/login -> http://java-backend:18080/auth/login
    method: 'post',
    data
  }) as any // Cast to any because interceptor modifies return type
}

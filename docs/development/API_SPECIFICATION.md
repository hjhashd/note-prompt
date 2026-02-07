# API 调用规范 (API Specification)

## 1. 技术栈
- **请求库**: [Axios](https://axios-http.com/)。
- **拦截器**: 统一处理请求头 (Token) 和响应格式转换。

## 2. 响应格式处理
为了简化业务逻辑调用，拦截器实现了以下自动转换：
- **原始结构**: `{ code: 0, data: { ... }, message: "success" }`
- **转换后**: 直接返回 `response.data.data`。
- **错误处理**: 如果 `code !== 0`，自动抛出异常。
- **状态码**: 统一使用 `code: 0` 作为业务成功标识。

## 3. 双后端集成 (Multi-Backend)
项目通过路径前缀区分不同的后端服务，Vite 代理会根据前缀转发并重写路径：
- `/api/python/*` -> 转发至 Python 服务，路径重写为 `/api/*`。
- `/api/java/*` -> 转发至 Java 服务，路径重写为 `/api/*`。

**关键配置 (vite.config.ts)**:
```typescript
'/api/python': {
  target: process.env.VITE_PYTHON_API_URL || 'http://localhost:34521',
  changeOrigin: true,
  rewrite: (path) => path.replace(/^\/api\/python/, '/api')
},
'/api/java': {
  target: process.env.VITE_JAVA_API_URL || 'http://localhost:18081',
  changeOrigin: true,
  rewrite: (path) => path.replace(/^\/api\/java/, '/api') // 必须保留 /api 前缀以匹配后端路由
}
```

## 4. Token 管理与登录集成
- **存储**: Token 和用户信息持久化存储在 `LocalStorage` 中，并通过 Pinia `useUserStore` 进行状态管理。
- **请求头**: 拦截器自动在每个请求中注入 `Authorization: Bearer <token>`。
- **登录流**:
    1. 调用 `auth.ts` 中的 `login` 接口。
    2. 成功后通过 `userStore.setToken` 存储。
    3. 路由守卫 `router.beforeEach` 会检查 Token，未登录用户强制跳转至 `/login`。

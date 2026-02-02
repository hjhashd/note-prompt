# API 调用规范 (API Specification)

## 1. 技术栈
- **请求库**: [Axios](https://axios-http.com/)。
- **拦截器**: 统一处理请求头 (Token) 和响应格式转换。

## 2. 响应格式处理
为了简化业务逻辑调用，拦截器必须实现以下自动转换：
- **原始结构**: `{ code: 200, data: { ... }, message: "success" }`
- **转换后**: 直接返回 `response.data.data`。
- **错误处理**: 如果 `code !== 200`，自动抛出异常并由统一拦截器处理消息提示。

```typescript
// 示例调用
const userInfo = await api.getUser(); // 直接获取到的是 data 里的内容
```

## 3. 双后端集成 (Multi-Backend)
项目同时接入两个后端服务，通过路径前缀区分：
- `/api/python/*`: 转发至 Python 后端服务。
- `/api/java/*`: 转发至 Java 后端服务。

## 4. 代理配置 (Proxy)
- **开发环境**: 由 Vite `server.proxy` 负责。
- **生产环境**: 由 Nginx `location` 负责。

## 5. Token 管理
- Token 统一存储在 Pinia Store 及 LocalStorage 中。
- 每个请求必须在 Header 中携带 `Authorization: Bearer <token>`。
- 拦截器需处理 401 状态码，实现自动重定向或错误提示。

# 智能网络访问准则 (Smart Network Access Guide)

## 1. 核心理念 (Core Philosophy)
**“相对即绝对 (Relative is Absolute)”**

为了适应内网直连 (192.168.x.x)、VPN 穿透 (127.0.0.1)、公网访问 (example.com) 等多种网络环境，系统严禁硬编码任何绝对 URL（如 `http://192.168.3.10:8080`）。所有资源和 API 请求必须基于**当前浏览器访问的 Origin** 进行相对寻址。

## 2. 动态地址解析策略 (Dynamic Resolution Strategy)

### 2.1 前端 API 请求
- **原则**: 永远不配置 `baseURL` 为绝对路径。
- **实现**:
    - 开发环境 (Vite): 使用 `/api` 前缀，由 `vite.config.ts` 代理到本地或远程后端。
    - 生产环境 (Nginx): 使用 `/api` 前缀，由 Nginx 将请求转发到 Docker 内部网络。
- **效果**:
    - 访问 `http://192.168.3.10:10086` -> API 请求 `http://192.168.3.10:10086/api/...`
    - 访问 `http://127.0.0.1:5000` (VPN) -> API 请求 `http://127.0.0.1:5000/api/...`
    - 访问 `https://app.com` (公网) -> API 请求 `https://app.com/api/...`

### 2.2 iframe 通信 (SmartBridge)
- **挑战**: 父子页面跨域，需要校验 `postMessage` 的 `origin`。
- **策略**: 采用“信任当前父级”或“白名单正则”机制，而不是硬编码 IP。
- **实现**: 在握手阶段动态获取父页面的 Origin，并建立信任会话。

## 3. 部署配置规范 (Configuration)

### 3.1 Nginx (生产环境)
必须使用相对路径代理，并正确传递 Host 头，确保后端能感知到真实的访问地址（虽然对于无状态 API 通常不需要，但对于重定向或 OAuth 很重要）。

```nginx
location /api/ {
    proxy_set_header Host $http_host;  # 关键：透传当前访问的域名/IP
    proxy_pass http://backend-service;
}
```

### 3.2 Docker Compose 环境变量注入
为了灵活管理后端端口（如避免 18080 端口冲突），系统支持通过环境变量动态配置：
- **JAVA_PORT**: Java 后端服务端口（默认 `18081`）。
- **PYTHON_PORT**: Python 后端服务端口（测试环境 `34521`，生产环境 `12543`）。

**配置示例**:
```yaml
environment:
  - JAVA_API_URL=${JAVA_API_URL:-http://java-backend:${JAVA_PORT:-18081}}
```

## 4. 常见问题排查 (Troubleshooting)

### 4.1 接口返回 500 或 404
- **检查代理重写规则**: 确保 `vite.config.ts` 中的 `rewrite` 规则正确。如果后端路由包含 `/api`，则重写时必须保留 `/api`。
- **端口冲突**: 确认本地是否有其他服务占用了 `18081` 或 `10086` 端口。
- **CURL 验证**: 优先使用 `curl -v` 验证后端接口是否可达，确认参数和 Header 正确。

### 4.2 复制按钮在内网 IP 访问时失效
- **现象**: 通过 VPN 或域名访问时复制正常，但直接访问 `http://192.168.x.x` 时点击复制无反应。
- **原因**: 浏览器安全策略限制。现代浏览器的 `navigator.clipboard` API 仅在“安全上下文 (Secure Context)”下可用。
    - 安全上下文包括：`https://`、`localhost`、`127.0.0.1`。
    - 普通内网 IP（如 `http://192.168.3.10`）被视为非安全上下文。
- **解决方案**: 
    1. **代码级兼容**: 系统已内置回退方案（使用隐藏 `textarea` + `document.execCommand('copy')`），在非安全环境下自动切换。
    2. **推荐做法**: 建议生产环境部署 HTTPS。
    3. **临时绕过**: 在 Chrome 中访问 `chrome://flags/#unsafely-treat-insecure-origin-as-secure`，将 `http://192.168.3.10:端口` 添加到白名单并重启浏览器。

## 5. 迁移指南 (Migration)
当从内网迁移到公网时，**无需修改任何代码或配置**。只要 DNS 解析正确，Nginx 能够响应请求，系统即可自动适应新的域名。

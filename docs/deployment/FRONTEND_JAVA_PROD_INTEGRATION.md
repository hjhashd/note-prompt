# 前端生产容器与 Java 后端生产容器对接指南

## 1. 架构概述

```
┌─────────────────────────────────────────────────────────────────┐
│                         宿主机 (Host)                            │
│  ┌─────────────────────┐      ┌─────────────────────────────┐  │
│  │  前端生产容器        │      │     Java 后端生产容器        │  │
│  │  (note-prompt)      │◄────►│  (prompt-system-backend)    │  │
│  │                     │      │                             │  │
│  │  端口: 10086        │      │  端口: 12544                │  │
│  │  对外提供服务        │      │  连接生产数据库              │  │
│  └─────────────────────┘      └─────────────────────────────┘  │
│           │                              │                      │
│           ▼                              ▼                      │
│     Nginx 反向代理                  Spring Boot                 │
│     /api/java/* ──────────────────►  REST API                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## 2. 端口映射关系

| 服务 | 容器内端口 | 宿主机映射端口 | 用途 |
|------|-----------|---------------|------|
| 前端生产 | 80 | 10086 | 用户访问入口 |
| Java 后端生产 | 8080 | 12544 | API 服务 |

## 3. 网络配置说明

### 为什么使用宿主机内网 IP (192.168.3.10) 而不是 host.docker.internal?

| 对比项 | 宿主机内网 IP | host.docker.internal |
|--------|--------------|---------------------|
| 兼容性 | ✅ 所有环境通用 | ❌ Docker Desktop 特性，Linux 原生 Docker 不支持 |
| 公司内网 | ✅ 只要宿主机在内网可达即可 | ❌ 某些内网环境 DNS 解析可能失败 |
| 跨平台 | ✅ 稳定可靠 | ❌ 仅适用于开发环境 |

**生产环境推荐使用内网 IP**，确保在任何网络环境下容器都能正确访问宿主机上的后端服务。

## 4. 配置步骤

### 4.1 启动 Java 后端生产容器

```bash
cd /root/zzp/langextract-main/ljt/prompt-system-backend

# 确认 docker-compose.java.yml 配置正确
cat docker-compose.java.yml
```

**关键配置检查点：**
- `ports: - "12544:8080"` - 确保宿主机 12544 映射到容器 8080
- `SPRING_PROFILES_ACTIVE=prod` - 确保使用生产配置
- `DB_NAME=generating_reports` - 确保连接生产数据库

**启动命令：**
```bash
# 加载环境变量
source .env

# 启动 Java 生产容器
docker-compose -f docker-compose.java.yml up -d

# 检查日志确认启动成功
docker-compose -f docker-compose.java.yml logs -f
```

### 4.2 配置前端生产环境

编辑 `/root/zzp/langextract-main/ljt/note-prompt/.env` 文件：

```bash
# ==========================================
# 前端生产环境配置 - Java 后端对接
# ==========================================

# Java 后端生产地址（关键配置）
# 使用宿主机内网 IP，确保公司内网环境下容器可访问
JAVA_API_URL=http://192.168.3.10:12544

# Python 后端生产地址（如需）
PYTHON_API_URL=http://192.168.3.10:12543

# 前端应用端口
APP_PORT=10086
```

### 4.3 前端 docker-compose.prod.yml 配置

文件路径：`/root/zzp/langextract-main/ljt/note-prompt/docker-compose.prod.yml`

```yaml
version: '3.8'

services:
  note-prompt:
    extends:
      file: docker-compose.yml
      service: note-prompt
    ports:
      - "${APP_PORT:-10086}:80"
    environment:
      - VITE_APP_ENV=production
      # 从 .env 文件读取 Java 后端地址（使用宿主机内网 IP）
      - JAVA_API_URL=${JAVA_API_URL:-http://192.168.3.10:12544}
      - PYTHON_API_URL=${PYTHON_API_URL:-http://192.168.3.10:12543}
    logging:
      driver: "json-file"
      options:
        max-size: "100m"
        max-file: "3"
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 2G
        reservations:
          memory: 512M
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### 4.4 Nginx 反向代理配置

文件路径：`/root/zzp/langextract-main/ljt/note-prompt/docker/nginx/default.conf.template`

```nginx
server {
    listen 80;
    server_name localhost;

    # 增加解析器，防止后端容器未启动时 Nginx 启动失败
    resolver 127.0.0.11 valid=30s;

    # 静态资源
    location / {
        root /usr/share/nginx/html;
        index index.html index.htm;
        try_files $uri $uri/ /index.html;
    }

    # ==========================================
    # Java 后端代理配置（生产环境）
    # ==========================================
    location /api/java/ {
        # 从环境变量读取 Java 后端地址
        set $java_upstream ${JAVA_API_URL};
        proxy_pass $java_upstream;
        
        # 透传原始 Host 头
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 重写路径：/api/java/xxx -> /api/xxx
        rewrite ^/api/java/(.*)$ /api/$1 break;
    }

    # Python 后端代理配置（如需）
    location /api/python/ {
        set $python_upstream ${PYTHON_API_URL};
        proxy_pass $python_upstream;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        
        # 支持 SSE 流式传输
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_buffering off;
        proxy_cache off;
        chunked_transfer_encoding off;

        rewrite ^/api/python/(.*)$ /api/$1 break;
    }

    # 错误页面
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
```

## 5. 启动流程

### 5.1 完整启动命令

```bash
# 1. 进入前端项目目录
cd /root/zzp/langextract-main/ljt/note-prompt

# 2. 确认 .env 配置正确
cat .env | grep JAVA_API_URL
# 预期输出: JAVA_API_URL=http://192.168.3.10:12544

# 3. 停止旧容器（如果存在）
docker-compose -f docker-compose.prod.yml down

# 4. 重新构建镜像（配置变更后必须重建）
docker-compose -f docker-compose.prod.yml build --no-cache

# 5. 启动前端生产容器
docker-compose -f docker-compose.prod.yml up -d

# 6. 检查容器状态
docker-compose -f docker-compose.prod.yml ps
```

### 5.2 验证对接成功

```bash
# 1. 检查前端容器环境变量
docker exec note-prompt env | grep JAVA

# 2. 检查 Nginx 配置是否正确加载
docker exec note-prompt cat /etc/nginx/conf.d/default.conf | grep -A5 "location /api/java"

# 3. 从容器内部测试 Java 后端连通性
docker exec note-prompt curl -v http://192.168.3.10:12544/api/health

# 4. 从宿主机测试完整链路
curl -v http://localhost:10086/api/java/v1/prompts
```

## 6. 常见问题排查

### 6.1 问题：前端无法访问 Java 后端

**排查步骤：**

```bash
# 1. 确认 Java 容器运行状态
docker ps | grep prompt-system-backend

# 2. 检查 Java 容器日志
docker logs prompt-system-backend

# 3. 从宿主机直接测试 Java 后端
curl http://localhost:12544/api/v1/prompts

# 4. 进入前端容器测试网络连通性
docker exec -it note-prompt sh
# 在容器内执行:
ping 192.168.3.10
wget -O- http://192.168.3.10:12544/api/v1/prompts
```

### 6.2 问题：Nginx 代理失败

**排查步骤：**

```bash
# 1. 查看 Nginx 错误日志
docker exec note-prompt tail -f /var/log/nginx/error.log

# 2. 检查环境变量是否正确传入
docker exec note-prompt env | grep API

# 3. 验证 Nginx 配置文件语法
docker exec note-prompt nginx -t
```

### 6.3 问题：数据库连接错误

**确认 Java 后端连接的是生产库：**

```bash
# 查看 Java 容器环境变量
docker exec prompt-system-backend env | grep DB

# 预期输出：
# DB_NAME=generating_reports
# DB_HOST=192.168.3.10
```

## 7. 回滚方案

如果生产环境出现问题，快速回滚到测试环境：

```bash
cd /root/zzp/langextract-main/ljt/note-prompt

# 修改 .env 指回测试环境
cat > .env << 'EOF'
JAVA_API_URL=http://192.168.3.10:18081
PYTHON_API_URL=http://192.168.3.10:34521
APP_PORT=10086
EOF

# 重启前端容器
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
```

## 8. 配置汇总

| 配置文件 | 关键配置项 | 生产值 |
|---------|-----------|--------|
| `.env` | `JAVA_API_URL` | `http://192.168.3.10:12544` |
| `docker-compose.java.yml` | `ports` | `"12544:8080"` |
| `docker-compose.java.yml` | `SPRING_PROFILES_ACTIVE` | `prod` |
| `docker-compose.java.yml` | `DB_NAME` | `generating_reports` |
| `docker-compose.prod.yml` | `extra_hosts` | `host.docker.internal:host-gateway` |

## 8. 测试验证清单

- [ ] Java 生产容器已启动（端口 12544）
- [ ] Java 连接生产数据库 `generating_reports`
- [ ] 前端生产容器已启动（端口 10086）
- [ ] 前端容器能访问 `host.docker.internal:12544`
- [ ] Nginx 配置正确加载了 `JAVA_API_URL`
- [ ] 通过 `http://localhost:10086/api/java/*` 能访问 Java API
- [ ] 前端页面功能正常（提示词列表、详情等）

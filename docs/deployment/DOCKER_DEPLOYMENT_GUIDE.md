# Docker 部署规范 (Docker Deployment Guide)

## 1. 核心原则 (Core Principles)
- **环境隔离**: 区分测试环境 (Staging) 和生产环境 (Production)。
- **环境变量注入**: 严禁在镜像中硬编码配置或使用 `.env` 文件。所有配置通过 Docker 容器运行时注入。
- **镜像一致性**: 编译产物打包入 Nginx 镜像，确保环境一致性。

## 2. 环境变量 (Environment Variables)
系统必须支持以下环境变量的注入：
- `VITE_APP_ENV`: 环境标识 (`staging` / `production`)。
- `VITE_PYTHON_API_URL`: Python 后端 API 地址。
- `VITE_JAVA_API_URL`: Java 后端 API 地址。

> **注意**: 在前端运行时注入环境变量通常需要通过 Nginx 替换占位符或在 `window` 对象上挂载配置。本项目采用 Nginx 代理方案。

## 3. Docker 架构
- **基础镜像**: `nginx:stable-alpine`。
- **构建阶段**: 使用 `node` 镜像进行多阶段构建，减少最终镜像体积。
- **Nginx 配置**: 负责静态资源分发及 API 代理转发。

## 4. 部署流程
1. **测试环境**: `docker-compose -f docker-compose.staging.yml up -d`
2. **生产环境**: `docker-compose -f docker-compose.prod.yml up -d`

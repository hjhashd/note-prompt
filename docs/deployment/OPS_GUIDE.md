# 运维操作指南 (Ops Guide)

## 1. 概览
本项目采用 Git + Docker 的自动化部署与回滚机制。所有脚本位于项目根目录下，无需记忆复杂命令。

## 2. 远程仓库
- **Origin**: `https://github.com/hjhashd/note-prompt`
- **操作**: 脚本会自动处理推送，但请确保您有相应的推送权限（SSH Key 或 Token）。

## 3. 脚本说明

### 🚀 部署 (Deploy)
```bash
./deploy.sh
```
**功能**:
1. 检查并提交代码（Git Commit）。
2. 创建带时间戳的 Tag（如 `backup-20240202-120000`）。
3. 推送到远程仓库。
4. 重启 Docker 生产环境 (`start-prod.sh`)。

### 🔄 回滚 (Rollback)
```bash
./rollback.sh
```
**功能**:
1. 列出最近 10 个备份 Tag。
2. 交互式选择要回退的版本。
3. 自动切换代码并重启生产环境。

### 🛠 开发环境 (Dev)
```bash
./start-dev.sh  # 启动
./stop-dev.sh   # 停止
```
**特点**:
- 挂载本地 `src/` 目录，支持热重载 (Hot Reload)。
- 运行在 5173 端口。

### 🏭 生产环境 (Prod)
```bash
./start-prod.sh # 启动
./stop-prod.sh  # 停止
```
**特点**:
- 基于 Nginx 的静态构建。
- 运行在 10086 端口 (默认)。

## 4. 常见问题
- **鉴权失败**: 如果 `git push` 失败，请配置 git credential helper 或使用 SSH 方式。
- **端口冲突**: 修改 `.env` 或 `docker-compose.yml` 中的端口映射。

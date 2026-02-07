#!/bin/bash
cd "$(dirname "$0")"
echo "启动 Docker 开发环境 (挂载本地源码)..."
docker-compose -p note-prompt-dev -f docker-compose.dev.yml up -d --build
echo "开发环境运行在: http://localhost:5173"

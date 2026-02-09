#!/bin/bash

# 智能路径跳转
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛑 正在停止生产环境..."
docker-compose -p note-prompt-prod -f docker-compose.prod.yml down
echo "✅ 生产环境已停止"

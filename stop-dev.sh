#!/bin/bash

# 智能路径跳转
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "🛑 正在停止开发环境..."
docker-compose -p note-prompt-dev -f docker-compose.dev.yml down
echo "✅ 开发环境已停止"

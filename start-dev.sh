#!/bin/bash

# 智能路径跳转：确保在脚本所在目录执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "------------------------------------------------"
echo "🚀 正在启动 Docker 开发环境 (挂载本地源码)..."
echo "------------------------------------------------"

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ 错误: Docker 未启动，请先启动 Docker！"
    exit 1
fi

# 启动容器
if docker-compose -p note-prompt-dev -f docker-compose.dev.yml up -d --build; then
    echo ""
    echo "✅ 开发环境已就绪！"
    echo "🌐 访问地址: http://localhost:5173"
    echo ""
    echo "💡 智能提示 - 如何查看日志："
    echo "   1. 查看所有日志:    docker-compose -p note-prompt-dev logs -f"
    echo "   2. 查看前端日志:    docker-compose -p note-prompt-dev logs -f note-prompt"
    echo "------------------------------------------------"
else
    echo "❌ 启动失败，请检查 docker-compose.dev.yml 配置"
    exit 1
fi

#!/bin/bash

# 智能路径跳转：确保在脚本所在目录执行
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "------------------------------------------------"
echo "🚀 正在启动生产环境..."
echo "------------------------------------------------"

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ 错误: Docker 未启动，请先启动 Docker！"
    exit 1
fi

# 停止旧容器
docker-compose -p note-prompt-prod -f docker-compose.prod.yml down

# 启动新容器
if docker-compose -p note-prompt-prod -f docker-compose.prod.yml up -d --build; then
    echo ""
    echo "✅ 生产环境已成功启动！"
    echo "🌐 访问端口: ${APP_PORT:-10086}"
    echo ""
    echo "💡 智能提示 - 如何查看日志："
    echo "   1. 查看实时日志:    docker-compose -p note-prompt-prod logs -f"
    echo "   2. 检查健康状态:    docker ps --filter name=note-prompt-prod"
    echo "------------------------------------------------"
    exit 0
else
    echo "❌ 生产环境启动失败！请检查配置或日志"
    exit 1
fi

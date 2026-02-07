#!/bin/bash
cd "$(dirname "$0")"
docker-compose -p note-prompt-prod -f docker-compose.prod.yml down
if docker-compose -p note-prompt-prod -f docker-compose.prod.yml up -d --build; then
    echo "生产环境已启动"
    exit 0
else
    echo "生产环境启动失败！"
    exit 1
fi

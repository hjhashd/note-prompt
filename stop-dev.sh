#!/bin/bash
cd "$(dirname "$0")"
docker-compose -f docker-compose.dev.yml down
echo "开发环境已停止"

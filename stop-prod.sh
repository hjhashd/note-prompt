#!/bin/bash
cd "$(dirname "$0")"
docker-compose -f docker-compose.prod.yml down
echo "生产环境已停止"

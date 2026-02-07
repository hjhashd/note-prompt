#!/bin/bash
cd "$(dirname "$0")"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Note Prompt Rollback System ===${NC}"

# 1. 获取最近 10 个备份标签
echo "最近的备份列表:"
tags=($(git tag --sort=-creatordate | head -n 10))

if [ ${#tags[@]} -eq 0 ]; then
    echo -e "${RED}没有找到备份标签！${NC}"
    exit 1
fi

for i in "${!tags[@]}"; do
    echo "[$i] ${tags[$i]}"
done

# 2. 选择版本
read -p "请输入要回滚的版本序号 (0-$((${#tags[@]}-1))): " index

if [[ ! "$index" =~ ^[0-9]+$ ]] || [ "$index" -ge "${#tags[@]}" ]; then
    echo -e "${RED}无效的序号！${NC}"
    exit 1
fi

target_tag=${tags[$index]}
echo -e "${GREEN}正在回滚到: $target_tag${NC}"

# 3. 执行回滚
git checkout $target_tag

# 4. 重启环境
echo -e "${GREEN}重启生产环境...${NC}"
./start-prod.sh

echo -e "${GREEN}=== 回滚完成 ===${NC}"
echo "注意：当前处于 'detached HEAD' 状态。如需继续开发，请执行 'git checkout main'。"

#!/bin/bash
set -e

# 确保脚本在项目目录下执行
cd "$(dirname "$0")" || exit 1

# 加载颜色配置 (结合项目原有风格)
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}📦 Starting Deployment Workflow...${NC}"

# 0. 权限检查：确保是以 cqj 用户运行
CURRENT_USER=$(whoami)
if [ "$CURRENT_USER" != "cqj" ]; then
    echo -e "${RED}❌ Error: This script must be run as user 'cqj'. Current user is '$CURRENT_USER'.${NC}"
    echo "💡 Please switch user: su - cqj"
    exit 1
fi

# 1. 自动检测本地是否有未提交的代码
if [ -n "$(git status --porcelain)" ]; then
    echo -e "⚠️  ${RED}Uncommitted changes detected.${NC}"
    # 提示输入说明并 commit
    read -p "📝 Enter commit message: " msg
    if [ -z "$msg" ]; then
        echo -e "${RED}❌ Commit message cannot be empty. Aborting.${NC}"
        exit 1
    fi
    git add .
    git commit -m "$msg"
    echo -e "${GREEN}✅ Changes committed.${NC}"
else
    echo -e "${GREEN}✅ No uncommitted changes found. Skipping commit.${NC}"
fi

# 2. 自动创建一个带时间戳的 Git 标签
TAG_NAME="backup-$(date +%Y%m%d-%H%M%S)"
echo -e "${GREEN}🏷️  Creating git tag: $TAG_NAME${NC}"
git tag "$TAG_NAME"

# 3. 将代码和标签推送到远程仓库 (结合项目实际情况，使用 origin)
echo -e "${GREEN}☁️  Pushing code and tags to remote (origin)...${NC}"
# 获取当前分支名称
CURRENT_BRANCH=$(git branch --show-current)

# 使用 if 明确检查推送结果
if git push origin "$CURRENT_BRANCH" && git push origin "$TAG_NAME"; then
    echo -e "${GREEN}✅ Git push successful.${NC}"
else
    echo -e "${RED}❌ Error: Git push failed. Deployment aborted to keep production consistent with repository.${NC}"
    exit 1
fi

# 4. 调用 start-prod.sh 重启生产容器
echo -e "${GREEN}🔄 Restarting production container...${NC}"
if ./start-prod.sh; then
    echo -e "${GREEN}🎉 Deployment successfully completed!${NC}"
    echo -e "${GREEN}🔖 Backup Tag: $TAG_NAME${NC}"
else
    echo -e "${RED}❌ Error: Production container failed to start.${NC}"
    exit 1
fi

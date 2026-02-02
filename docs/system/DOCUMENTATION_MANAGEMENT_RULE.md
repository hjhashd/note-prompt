# 文档管理规则 (Documentation Management Rules)

## 1. 语言规范 (Language)
- **主要语言**: 中文 (Chinese)。
- **文件名**: 英文，使用 kebab-case (例如: `user-guide.md`)。
- **目录名**: 英文，使用 kebab-case (例如: `api-reference/`)。

## 2. 目录结构 (Directory Structure)
- `docs/` 根目录下**严禁**存放散乱的 Markdown 文件。
- 所有文档必须根据其内容归类到相应的子目录中。
- 推荐分类:
    - `docs/system/`: 系统级文档、规则、架构图。
    - `docs/development/`: 开发指南、API 规范、技术栈说明。
    - `docs/user/`: 用户手册、操作指南。
    - `docs/deployment/`: 部署运维文档。

## 3. AI 操作准则 (AI Guidelines)
- **Before Creation**: 在创建新文档前，先检查是否存在类似文档。如果存在，优先更新现有文档。
- **Maintenance**: 每次修改代码或架构时，检查是否有相关文档需要同步更新。
- **Consistency**: 保持文档风格一致，遵循 Markdown 标准。

## 4. Skill 同步 (Skill Sync)
- 核心文档类别应对应一个 `.trae/skills/` 下的 Skill (如 `doc-manager`)，以便 AI 能够快速检索和理解。

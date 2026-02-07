# 提示词管理模块 API 设计文档

## 1. 概述
本文档描述了提示词（Prompt）管理模块的前后端交互接口设计。旨在为前端 `HomeView` 及 `PromptList` 组件提供高效、可维护的数据支持。

## 2. 接口设计原则
- **RESTful 风格**: 使用标准的 HTTP 方法和状态码。
- **分页加载**: 默认每页返回 12 条数据，减轻前端渲染压力和后端传输压力。
- **扁平化结构**: 响应数据结构尽量扁平，方便前端直接使用。
- **驼峰命名**: JSON 字段使用小驼峰（camelCase）命名。

## 3. 接口详情

### 3.1 获取提示词列表

**URL**: `/api/v1/prompts`
**Method**: `GET`
**Description**: 分页获取提示词列表，支持搜索、筛选和排序。

#### 请求参数 (Query Parameters)

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
| :--- | :--- | :--- | :--- | :--- |
| `page` | Integer | 否 | 1 | 页码，从 1 开始 |
| `pageSize` | Integer | 否 | 12 | 每页数量 |
| `keyword` | String | 否 | - | 搜索关键词（匹配标题、描述、标签） |
| `filter` | String | 否 | `all` | 筛选范围：<br>`all`: 全部（我有权限看到的）<br>`my`: 我创建的<br>`favorites`: 我收藏的<br>`shared`: 公共/分享的 |
| `sort` | String | 否 | `updatedAt` | 排序字段：<br>`updatedAt`: 更新时间<br>`createdAt`: 创建时间<br>`views`: 浏览量<br>`likes`: 点赞数 |
| `order` | String | 否 | `desc` | 排序方向：`asc`, `desc` |

#### 响应结构 (Response Body)

```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 100,
    "page": 1,
    "pageSize": 12,
    "list": [
      {
        "id": 1,
        "uuid": "550e8400-e29b-41d4-a716-446655440000",
        "title": "Python 数据分析助手",
        "description": "专注于 Pandas 和 NumPy 的数据处理专家...",
        "content": "你是一个 Python 数据分析专家...",
        "tags": ["数据分析", "Python", "Pandas"],
        "author": {
          "id": 1001,
          "name": "张三",
          "avatar": "https://example.com/avatar.jpg" 
        },
        "stats": {
          "views": 128,
          "likes": 45,
          "favorites": 12
        },
        "updatedAt": "2023-10-27T10:00:00Z",
        "createdAt": "2023-10-26T10:00:00Z",
        "isLiked": false,
        "isFavorited": true
      }
    ]
  }
}
```

#### 数据库映射说明 (Backend Implementation Notes)

- **主表**: `ai_prompts`
- **关联查询**:
  - `tags`: 需要关联 `ai_prompt_tag_relation` 和 `ai_prompt_tags` 表。建议使用子查询或应用层组装，避免 N+1 问题。
  - `author`: 对应 `ai_prompts.user_id` 和 `ai_prompts.user_name`。
  - `isLiked`/`isFavorited`: 需要查询 `ai_user_interactions` 表，检查当前用户是否对该 Prompt 有 `action_type=1`(点赞) 或 `action_type=2`(收藏) 的记录。

### 3.2 字段映射对照表

| 前端字段 | 数据库字段 (`ai_prompts`) | 说明 |
| :--- | :--- | :--- |
| `id` | `id` | 主键 |
| `title` | `title` | 标题 |
| `description` | `description` | 描述 |
| `content` | `content` | 内容 |
| `stats.views` | `view_count` | 浏览量 |
| `stats.likes` | `like_count` | 点赞量 |
| `updatedAt` | `update_time` | 更新时间 |
| `author.name` | `user_name` | 作者名 |

## 4. 前端对接建议 (TypeScript Interface)

```typescript
// types/prompt.ts

export interface PromptAuthor {
  id: number;
  name: string;
  avatar?: string;
}

export interface PromptStats {
  views: number;
  likes: number;
  favorites: number;
}

export interface PromptItem {
  id: number;
  uuid: string;
  title: string;
  description: string;
  content: string;
  tags: string[];
  author: PromptAuthor;
  stats: PromptStats;
  updatedAt: string;
  createdAt: string;
  isLiked: boolean;
  isFavorited: boolean;
}

export interface PromptListResponse {
  total: number;
  page: number;
  pageSize: number;
  list: PromptItem[];
}
```

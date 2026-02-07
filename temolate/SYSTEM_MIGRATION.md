# NotePrompt 原型系统迁移指南

本文档旨在说明如何将 **NotePrompt - 智能提示词工作室** 的原型页面迁移到你的项目中。

## 1. 迁移目录结构

建议在你的项目根目录下创建一个 `template` 文件夹，并将以下所有 HTML 文件放入该文件夹中：

```text
你的项目根目录/
└── template/
    ├── index.html
    ├── noteprompt_final.html
    ├── prompt_studio_optimized.html
    ├── prompt_optimus.html
    ├── admin_dashboard.html
    ├── my_stats.html
    ├── login.html
    ├── my_collections.html
    └── public_folders.html
```

## 2. 核心 HTML 文件列表 (相对路径)

如果你只想搬走系统的样子（UI/UX），你需要获取以下位于 `template/` 目录下的核心页面：

### **核心框架与导航**
- **noteprompt_final.html**: **系统主控制台**。这是整个系统的入口，包含了侧边栏导航、提示词列表展示、搜索过滤以及分类管理功能。
- **index.html**: **引导页**。负责将用户重定向到主控制台。

### **功能模块**
- **prompt_studio_optimized.html**: **提示词编辑器**。用于创建和编辑具体的提示词，包含 AI 优化对话框。
- **prompt_optimus.html**: **高级优化器**。专注于提示词的深度优化和调优界面。
- **admin_dashboard.html**: **管理仪表盘**。展示系统的全局统计数据。
- **my_stats.html**: **个人统计页**。展示用户个人的使用数据。

### **辅助页面**
- **login.html**: 登录界面。
- **my_collections.html**: 个人收藏夹。
- **public_folders.html**: 公共库/文件夹页面。

---

## 3. 页面间的交互逻辑

虽然目前是静态原型，但页面之间通过以下逻辑相互关联（假设它们都在同一个目录下）：

1.  **导航跳转**:
    - `noteprompt_final.html` 的左侧侧边栏是核心导航。点击菜单项会通过相对路径跳转到对应的功能页面（如 `admin_dashboard.html`）。
2.  **创建/编辑流**:
    - 在主控制台点击“新建提示词”或卡片，会跳转到 `prompt_studio_optimized.html`。
    - 在编辑器中，点击“高级优化”会跳转到 `prompt_optimus.html`。
3.  **身份验证流**:
    - 未登录用户会被引导至 `login.html`，登录成功后返回 `noteprompt_final.html`。

---

## 4. 迁移建议

- **资源路径**: 确保 `template/` 文件夹内的文件在引用图片或其他资源时使用正确的相对路径。
## 5. 迁移进度跟踪 (Progress Tracking)

目前迁移工作已启动，正在从传统的静态 HTML 原型向现代 Vue 3 + Vite 架构迁移。

### 5.1 已完成项 (Completed)
- [x] **项目基础架构搭建**: Vue 3 (Composition API) + Vite + TypeScript + Tailwind CSS。
- [x] **全局设计系统 (UI Design System)**: 
    - 建立了基于 Indigo 和 Slate 色系的现代 SaaS 视觉风格。
    - 实现全局毛玻璃 (Glassmorphism) 效果和柔和阴影规范。
    - 文档参考: `docs/design/ui-design-system.md`。
- [x] **首页 (Dashboard) 核心组件化**:
    - `noteprompt_final.html` 已成功拆分为多个独立组件。
    - [Sidebar.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/Sidebar.vue): 现代侧边栏导航，支持收起/展开。
    - [TagDirectory.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/TagDirectory.vue): 树形分类管理。
    - [PromptList.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/PromptList.vue): 响应式卡片流，支持搜索与筛选。
    - [HomeView.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/views/HomeView.vue): 首页整体布局组装。

### 5.2 进行中/待处理 (In Progress / Pending)
- [ ] **提示词编辑器 (Prompt Studio)**: 迁移 `prompt_studio_optimized.html`，实现 AI 优化交互。
- [ ] **高级优化器 (Prompt Optimus)**: 迁移 `prompt_optimus.html`。
- [ ] **管理后台与统计**: 迁移 `admin_dashboard.html` 和 `my_stats.html`。
- [ ] **交互与状态管理**: 使用 Pinia 实现组件间通信（如搜索同步、分类筛选）。
- [ ] **API 对接**: 将模拟数据替换为后端实际接口。


# UI 界面改造计划：类 NotebookLM 极简风格

本计划旨在将系统的 UI 风格统一为用户提供的图片样式：**侧边栏纯白，内容区浅灰背景，内容块为纯白卡片**。

## 1. 核心视觉规范 (Design Tokens)

需要更新全局 CSS 变量，确保颜色和阴影的一致性。

- **背景色 (Backgrounds)**:
    - 侧边栏 & 卡片背景: `#FFFFFF` (纯白)
    - 主内容区背景: `#F0F4F9` (浅灰)
- **阴影 (Shadows)**:
    - 移除玻璃拟态 (Glassmorphism) 的模糊效果。
    - 使用极细的边框或非常柔和的阴影来区分层级。
- **圆角 (Border Radius)**:
    - 维持现有的 `12px` - `24px` 范围，确保现代化感。

## 2. 改造步骤

### 第一步：更新全局主题变量
修改 [studio-theme.css](file:///root/zzp/langextract-main/ljt/note-prompt/src/assets/studio-theme.css) 中的基础变量。

```css
:root {
    --bg-primary: #F0F4F9;    /* 内容区背景 - 浅灰 */
    --bg-surface: #FFFFFF;    /* 卡片 & 面板背景 - 纯白 */
    --sidebar-bg: #FFFFFF;    /* 侧边栏背景 - 纯白 */
    --border-subtle: rgba(0, 0, 0, 0.04);
}
```

### 第二步：侧边栏改造
修改 [Sidebar.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/Sidebar.vue)，移除玻璃拟态效果。

- **操作**:
    - 将 `background` 设置为 `var(--sidebar-bg)`。
    - 移除 `backdrop-filter` 和 `-webkit-backdrop-filter`。
    - 将 `border-right` 调整为更浅的颜色或柔和阴影。

### 第三步：分类目录面板改造
修改 [TagDirectory.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/TagDirectory.vue)，使其成为纯白卡片。

- **操作**:
    - 移除 `.glass-card` 类或修改其定义。
    - 确保背景为 `var(--bg-surface)`。
    - 增加柔和的阴影 `box-shadow: var(--shadow-sm)`。

### 第四步：内容区工具栏与列表改造
修改 [PromptList.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/components/layout/PromptList.vue)。

- **工具栏 (Toolbar)**:
    - 移除背景的透明度和模糊效果。
    - 设置背景为 `var(--bg-surface)`。
- **提示词卡片 (Prompt Card)**:
    - 确保背景为纯白。
    - 调整悬停效果，使其阴影更柔和。

### 第五步：布局容器调整
确保 [HomeView.vue](file:///root/zzp/langextract-main/ljt/note-prompt/src/views/HomeView.vue) 中的 `.main-content` 正确应用了浅灰背景。

## 3. 验收标准
1. [ ] 侧边栏不再有透明/模糊感，呈现纯白色。
2. [ ] 内容区域（卡片之外的部分）有明显的浅灰色。
3. [ ] 所有的功能块（分类目录、搜索框、提示词卡片）都是纯白色背景。
4. [ ] 整体视觉层次通过背景色差而非重阴影来体现。

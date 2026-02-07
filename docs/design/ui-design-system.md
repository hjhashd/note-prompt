# UI 设计系统规范 (UI Design System)

本文档旨在统一 NotePrompt 项目的视觉风格和交互设计，确保未来开发的一致性。

## 1. 设计理念 (Design Philosophy)

*   **傻瓜式设计原则 (Foolproof Design)**: 
    *   **极度直观**: 把用户当成“傻子”来设计，任何操作都应该显而易见，不需要思考。
    *   **防错与易恢复**: 关键操作（如侧边栏收起）必须易于撤销/恢复，按钮位置要独立且醒目，避免误触。
    *   **清晰的视觉反馈**: 任何交互都应有即时且符合物理直觉的反馈。

*   **NotebookLM 风格 (Modern & Floating)**: 采用 Google NotebookLM 的设计语言，强调内容的“悬浮感”和界面的“通透感”。
*   **沉浸式背景**: 使用 Google 风格的浅灰背景 (`#F0F4F9`)，让白色卡片内容更加突出。

## 2. 色彩系统 (Color System)

设计变量定义在 [studio-theme.css](file:///root/zzp/langextract-main/ljt/note-prompt/src/assets/studio-theme.css) 中，并在 `main.ts` 中全局引入，覆盖默认的基础样式。

### 背景色 (Backgrounds)
*   `--bg-primary`: `#F0F4F9` (全局主背景，Google Light Gray，比默认的 gray-50 更暖/深一点)
*   `--bg-surface`: `#FFFFFF` (卡片/浮层背景)
*   `--bg-secondary`: `#F8FAFC` (次级区域背景/输入框背景)

### 文本色 (Typography)
*   `--text-primary`: `#1F2937` (主要文字/黑色按钮背景)
*   `--text-secondary`: `#4B5563` (次要文字/导航项)
*   `--text-inverse`: `#FFFFFF` (反色文字，用于深色按钮)

### 品牌色 (Accents)
*   `--primary`: `#1A73E8` (Google Blue，用于链接/高亮)
*   `--primary-light`: `#E8F0FE` (激活态背景)

## 3. 核心组件规范 (Component Guidelines)

### 3.1 布局容器 (Layout Containers)
*   **悬浮卡片 (Floating Cards)**:
    *   主工作区采用悬浮卡片布局，而非铺满屏幕。
    *   **类名**: `.panel-card` (推荐) 或自定义样式。
    *   **圆角**: `--radius-xl` (24px)
    *   **阴影**: `--shadow-sm` (常态), `--shadow-card` (悬停/强调)
    *   **边距**: 容器之间保留 `--layout-gap` (16px) 的间距，透出底部背景。
    *   **边框**: `1px solid rgba(0,0,0,0.02)` (极细微边框)

*   **通透背景**:
    *   `Sidebar` 和 `Editor` 的外层容器背景设为 `transparent`，维护整体通透感。

### 3.2 按钮与交互 (Buttons & Interactions)
*   **主按钮**:
    *   **形状**: Pill Shape (24px 圆角)
    *   **样式**: 纯黑背景 (`--text-primary`) + 白色文字，悬停时加深或添加阴影。
    *   **示例**: Header 区域的 "Save", "Run Test" 按钮。
*   **次级按钮/图标**:
    *   **形状**: 圆形或胶囊形。
    *   **样式**: 透明背景，悬停时显示浅灰背景 (`--bg-secondary` 或 `rgba(0,0,0,0.05)`)。

### 3.3 导航与输入 (Navigation & Inputs)
*   **侧边栏 (Sidebar)**:
    *   背景透明，无右侧边框。
    *   导航项选中态为胶囊形背景 (`--primary-light` 或浅灰)，文字高亮。
*   **输入框**:
    *   搜索框、下拉选框均采用 Pill Shape (全圆角)。
    *   移除默认边框，使用浅灰色背景 (`--bg-secondary`)，聚焦时加深或显示微弱边框。

## 4. 间距与圆角 (Spacing & Radius)

*   **圆角系统**:
    *   `--radius-sm`: 8px (小型元素)
    *   `--radius-md`: 12px (标准元素)
    *   `--radius-lg`: 16px (大型卡片)
    *   `--radius-xl`: 24px (核心面板/主按钮 - **主要使用**)
    *   `--radius-2xl`: 28px (超大容器)

*   **间距**:
    *   `--layout-gap`: 16px (面板间距)

## 5. 图标系统 (Iconography)

*   **风格**: 简约线框风格 (Simple Stroked)，保持 2px 描边宽度。
*   **库**: 使用 `lucide-vue-next`。
*   **原则**:
    *   避免使用多彩 (Colorful) 或填充风格的图标作为主要 UI 元素。
    *   图标应保持单色，通常跟随文本颜色 (`--gray-500` 或 `--gray-600`)。
    *   功能性图标（如复制、点赞）应具备清晰的交互反馈。

## 6. 通用组件 (Common Components)

### 复制按钮 (CopyButton)
*   **组件路径**: `src/components/common/CopyButton.vue`
*   **用途**: 用于复制文本内容到剪贴板。
*   **交互**: 点击后图标变为对号 (Check)，并在 2秒后恢复。
*   **样式**: 默认透明背景，悬停显示浅灰背景，激活态为绿色。

## 7. 代码实现参考 (Implementation Reference)

### 样式文件
所有 Studio 相关的样式变量应引用：
`src/assets/studio-theme.css`

### Vue 组件示例

```vue
<style scoped>
.panel-card {
  /* 典型的悬浮卡片样式 */
  background: var(--bg-surface);
  border-radius: var(--radius-xl); /* 24px */
  box-shadow: var(--shadow-sm);
  border: 1px solid rgba(0,0,0,0.02); /* 极细微边框 */
}

.action-btn {
  /* 典型的胶囊按钮 */
  border-radius: 24px;
  background: var(--text-primary);
  color: var(--text-inverse);
}
</style>
```

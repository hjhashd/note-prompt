# 全局消息提示组件设计文档

## 概述

本项目引入了一个基于 Tailwind CSS 的现代化全局消息提示组件 (Toast/Notification)，旨在替代原生的 `alert()` 弹窗，提供更美观、一致的用户体验。

## 设计理念

- **Modern & Floating**: 采用悬浮卡片设计，支持亮色/暗色模式。
- **Type-Safe**: 基于 TypeScript 开发，提供完整的类型提示。
- **Global Access**: 通过 Composable (`useToast`) 实现全局调用，无需在每个组件中单独引入 UI。
- **Animation**: 使用 Vue `TransitionGroup` 实现流畅的进入和退出动画。

## 核心组件

### 1. `ToastContainer`
- **位置**: 全局挂载于 `App.vue`，默认位于屏幕右上角 (桌面端) 或 顶部居中 (移动端)。
- **功能**: 管理消息队列的渲染和动画。

### 2. `ToastItem`
- **样式**: 白色背景 (暗色模式为深灰色)，带有细微阴影和边框。
- **图标**: 根据消息类型 (`success`, `error`, `warning`, `info`) 显示不同的 Lucide 图标。

## 如何使用

### 在 Vue 组件中使用

只需引入 `useToast` composable 即可：

```typescript
import { useToast } from '@/composables/useToast'

// 在 setup 中获取 toast 方法
const { toast } = useToast()

// 调用
toast('操作成功！', 'success')
toast('发生错误，请重试', 'error')
toast('这是一条提示信息', 'info')
```

### 在非组件文件 (如 utils/request.ts) 中使用

由于 `useToast` 维护了全局响应式状态，可以在任何 JS/TS 文件中直接调用：

```typescript
import { useToast } from '@/composables/useToast'

export function handleData() {
  const { toast } = useToast()
  
  if (error) {
    toast('数据处理失败', 'error')
  }
}
```

## 参数说明

`toast(message, type, duration)`

- **message** (string): 提示内容。
- **type** (ToastType): `'success' | 'error' | 'warning' | 'info'` (默认: `'info'`)。
- **duration** (number): 显示时长，单位毫秒 (默认: `3000`)。

## 更改记录

- **Created**: `src/components/ui/Toast/ToastItem.vue` (UI 组件)
- **Created**: `src/components/ui/Toast/ToastContainer.vue` (容器组件)
- **Created**: `src/composables/useToast.ts` (状态管理)
- **Modified**: `src/App.vue` (集成 ToastContainer)
- **Modified**: `src/utils/request.ts` (替换 alert 为 toast)

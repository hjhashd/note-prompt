# AI Thought Process UI Pattern

## Overview
This document describes the standardized UI pattern for displaying AI "Chain of Thought" (CoT) reasoning in the Prompt Studio application. The goal is to provide a consistent, foldable, and distinct visualization of the AI's internal thinking process across all interface areas (Editor, Dialogue, and Test/Preview).

## Component: `ThinkBlock`

The core component is `ThinkBlock.vue`.

### Features
- **Collapsible**: Users can toggle the visibility of the thought process.
- **Distinct Styling**: Uses a different background color and icon to distinguish from the main response.
- **Markdown Support**: Renders the thought process using Markdown (if applicable).
- **Iconography**: Uses standard icons (BrainCircuit, Chevron) for consistency.
- **Scroll & Layout**:
  - No independent scrollbar (uses parent/page scroll).
  - No width constraints (fills available space).

### Usage

```vue
<script setup>
import ThinkBlock from '@/components/editor/ThinkBlock.vue'
</script>

<template>
  <ThinkBlock :content="aiThinkingContent" />
</template>
```

## Integration Guidelines

### 1. Data Parsing
When receiving streaming responses from the AI API, the application must parse the `<think>` tags to separate the reasoning content from the final output. It is important to handle the content appearing *before* the `<think>` tag (e.g., initial greetings).

**Standard Parsing Logic:**
```typescript
const thinkStart = fullResponse.indexOf('<think>')
const thinkEnd = fullResponse.indexOf('</think>')

if (thinkStart !== -1) {
  const preThink = fullResponse.substring(0, thinkStart)
  if (thinkEnd !== -1) {
    // Thought process complete
    thinkContent.value = fullResponse.substring(thinkStart + 7, thinkEnd)
    realContent.value = preThink + fullResponse.substring(thinkEnd + 8).trimStart()
  } else {
    // Thought process in progress
    thinkContent.value = fullResponse.substring(thinkStart + 7)
    realContent.value = preThink
  }
} else {
  // No thought tags (yet), treat as normal content
  realContent.value = fullResponse
}
```

### 2. UI Areas
This pattern should be applied to:
- **Editor Optimization**: Where the AI optimizes the prompt.
- **Chat/Dialogue**: In the conversation view (`StudioDialogue`).
- **Test/Config Panel**: In the "Quick Test" results area (`StudioConfig`).

## Styling & Libraries
- **Parsing Engine**: `markdown-it` (Version 14.1.0+)
- **CSS Foundation**: `github-markdown-css`
- **Iconography**: `lucide-vue-next` (BrainCircuit, ChevronDown, ChevronUp)

### Implementation Tip
To apply these styles globally:
1.  **Componentize**: Use `ThinkBlock.vue` as the universal container for AI reasoning.
2.  **Global Markdown Style**: Import `github-markdown-css` in `main.ts` or as a scoped import in common components to ensure all AI-generated content shares the same professional look.
3.  **Scoped Styling**: Use `:deep(.markdown-body)` to fine-tune AI output appearance inside specific parent containers without affecting global styles.

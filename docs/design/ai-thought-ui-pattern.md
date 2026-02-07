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
When receiving streaming responses from the AI API, the application must parse the `<think>` tags to separate the reasoning content from the final output.

**Standard Parsing Logic:**
```typescript
const thinkStart = fullResponse.indexOf('<think>')
if (thinkStart !== -1) {
  const thinkEnd = fullResponse.indexOf('</think>')
  if (thinkEnd !== -1) {
    // Thought process complete
    thinkContent.value = fullResponse.substring(thinkStart + 7, thinkEnd)
    realContent.value = fullResponse.substring(thinkEnd + 8).trimStart()
  } else {
    // Thought process in progress
    thinkContent.value = fullResponse.substring(thinkStart + 7)
    // Optionally hide realContent until thinking is done, or show partial
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

## Design Specifications
- **Background**: `#f8fafc` (Slate-50)
- **Border**: `1px solid #e2e8f0` (Slate-200)
- **Border Radius**: `12px`
- **Typography**: `14px`, Slate-600 (`#475569`)
- **Spacing**: `margin-bottom: 16px` to separate from main content.

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { getTagsTree } from '@/api/prompt'
import type { TagItem } from '@/types/prompt'

const props = defineProps<{
  parentId: number | null
}>()

const emit = defineEmits<{
  (e: 'select', id: number): void
}>()

const categories = ref<TagItem[]>([])
const subTags = ref<TagItem[]>([])

const findNode = (nodes: TagItem[], id: number): TagItem | null => {
  for (const node of nodes) {
    if (node.id === id) return node
    if (node.children) {
      const found = findNode(node.children, id)
      if (found) return found
    }
  }
  return null
}

const updateSubTags = () => {
  if (props.parentId === null || props.parentId === undefined) {
    // If no parent selected, show nothing (or could show L1)
    // Based on user request, sidebar has departments. 
    // If nothing selected, maybe we don't show sub-tags yet.
    // Or we could show L1. Let's start with showing nothing to keep it clean,
    // as Sidebar already shows L1.
    subTags.value = [] 
  } else {
    const node = findNode(categories.value, props.parentId)
    subTags.value = node?.children || []
  }
}

const fetchTags = async () => {
  try {
    const data = await getTagsTree()
    // Flatten root logic (same as TagDirectory)
    if (data && data.length > 0 && data[0].children) {
      categories.value = data[0].children
    } else {
      categories.value = data || []
    }
    updateSubTags()
  } catch (error) {
    console.error('Failed to fetch tags:', error)
  }
}

watch(() => props.parentId, updateSubTags)

onMounted(() => {
  fetchTags()
})
</script>

<template>
  <div class="sub-category-list" v-if="subTags.length > 0">
    <div class="tags-wrapper">
      <button
        v-for="tag in subTags"
        :key="tag.id"
        class="tag-chip"
        @click="$emit('select', tag.id)"
      >
        {{ tag.name }}
        <span v-if="tag.count" class="tag-count">{{ tag.count }}</span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.sub-category-list {
  padding: 12px 0;
  border-bottom: 1px solid var(--border-subtle, rgba(0,0,0,0.05));
  margin-bottom: 16px;
}

.tags-wrapper {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.tag-chip {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  background: var(--bg-surface);
  border: 1px solid var(--border-color, #e5e7eb);
  border-radius: 16px; /* Pill shape */
  font-size: 14px;
  color: var(--text-primary);
  cursor: pointer;
  transition: all 0.2s;
}

.tag-chip:hover {
  background: var(--bg-secondary, #f9fafb);
  border-color: var(--primary-300, #93c5fd);
  color: var(--primary, #2563eb);
}

.tag-count {
  font-size: 12px;
  color: var(--text-secondary);
  background: var(--bg-secondary);
  padding: 2px 6px;
  border-radius: 10px;
}

.tag-chip:hover .tag-count {
  background: var(--primary-100, #dbeafe);
  color: var(--primary);
}
</style>

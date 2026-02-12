<script setup lang="ts">
import { ref } from 'vue'
import TagDirectory from '@/components/layout/TagDirectory.vue'

const props = defineProps<{
  modelValue: number | null
}>()

const emit = defineEmits<{
  (e: 'update:modelValue', id: number | null): void
  (e: 'collapse', collapsed: boolean): void
}>()

const isCollapsed = ref(false)

const toggleDirectory = () => {
  isCollapsed.value = !isCollapsed.value
  emit('collapse', isCollapsed.value)
}

const handleSelect = (id: number | null) => {
  emit('update:modelValue', id)
}
</script>

<template>
  <div class="left-panel" :class="{ collapsed: isCollapsed }">
    <TagDirectory 
      :collapsed="isCollapsed" 
      :model-value="props.modelValue"
      @toggleCollapse="toggleDirectory" 
      @update:model-value="handleSelect"
    />
  </div>
</template>

<style scoped>
.left-panel {
  width: 300px;
  transition: width var(--transition-normal);
  height: 100%;
}

.left-panel.collapsed {
  width: 72px;
}

@media (max-width: 1024px) {
  .left-panel {
    width: 240px;
  }
  .left-panel.collapsed {
    width: 72px;
  }
}

@media (max-width: 768px) {
  .left-panel {
    width: 100%;
  }
}
</style>

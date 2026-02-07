<script setup lang="ts">
import { ref } from 'vue'
import { Copy, Check } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  text: string
  label?: string
}>()

const copied = ref(false)
const { toast } = useToast()

const handleCopy = async () => {
  try {
    await navigator.clipboard.writeText(props.text)
    copied.value = true
    toast('复制成功', 'success')
    setTimeout(() => {
      copied.value = false
    }, 2000)
  } catch (err) {
    console.error('Failed to copy:', err)
    toast('复制失败', 'error')
  }
}
</script>

<template>
  <button 
    class="copy-btn" 
    :class="{ copied, 'icon-only': !label }" 
    @click.stop="handleCopy" 
    :title="copied ? '已复制' : '复制'"
  >
    <transition name="scale" mode="out-in">
      <Check v-if="copied" class="icon" :size="16" />
      <Copy v-else class="icon" :size="16" />
    </transition>
    <span v-if="label" class="label">{{ copied ? '已复制' : label }}</span>
  </button>
</template>

<style scoped>
.copy-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  background: var(--bg-surface);
  border: 1px solid var(--border-subtle);
  color: var(--gray-600);
  padding: 6px 12px;
  border-radius: var(--radius-md);
  cursor: pointer;
  transition: all var(--transition-fast);
  height: 32px;
  box-shadow: var(--shadow-sm);
}

.copy-btn.icon-only {
  width: 32px;
  padding: 6px;
}

.copy-btn:hover {
  background: var(--bg-primary);
  color: var(--primary-600);
  border-color: var(--primary-200);
  box-shadow: var(--shadow-md);
}

.copy-btn.copied {
  color: var(--success);
  border-color: var(--success);
  background: rgba(16, 185, 129, 0.05);
}

.label {
  font-size: 13px;
  font-weight: 500;
}

.scale-enter-active,
.scale-leave-active {
  transition: all 0.2s ease;
}

.scale-enter-from,
.scale-leave-to {
  transform: scale(0.8);
  opacity: 0;
}
</style>

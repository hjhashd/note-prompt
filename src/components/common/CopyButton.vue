<script setup lang="ts">
import { ref } from 'vue'
import { Copy, Check } from 'lucide-vue-next'
import { useToast } from '@/composables/useToast'
import { copyToClipboard } from '@/utils/clipboard'

const props = defineProps<{
  text: string
  label?: string
}>()

const copied = ref(false)
const { toast } = useToast()

const handleCopy = async () => {
  const success = await copyToClipboard(props.text)
  if (success) {
    copied.value = true
    toast('复制成功', 'success')
    setTimeout(() => {
      copied.value = false
    }, 2000)
  } else {
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
  background: var(--bg-secondary);
  border: 1px solid rgba(0, 0, 0, 0.03);
  color: var(--text-secondary);
  padding: 6px 14px;
  border-radius: 24px;
  cursor: pointer;
  transition: all 0.2s ease;
  height: 32px;
}

.copy-btn.icon-only {
  width: 32px;
  padding: 6px;
}

.copy-btn:hover {
  background: var(--bg-primary);
  color: var(--text-primary);
  transform: translateY(-1px);
}

.copy-btn.copied {
  color: #137333;
  background: #e6f4ea;
  border-color: transparent;
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

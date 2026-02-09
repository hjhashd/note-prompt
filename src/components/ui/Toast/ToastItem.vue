<script setup lang="ts">
import { computed } from 'vue'
import { CheckCircle, AlertCircle, Info, AlertTriangle, X } from 'lucide-vue-next'
import type { Toast } from '@/composables/useToast'
import { useToast } from '@/composables/useToast'

const props = defineProps<{
  toast: Toast
}>()

const { removeToast } = useToast()

const iconComponent = computed(() => {
  switch (props.toast.type) {
    case 'success': return CheckCircle
    case 'error': return AlertCircle
    case 'warning': return AlertTriangle
    case 'info': return Info
    default: return Info
  }
})

const iconColorClass = computed(() => {
  switch (props.toast.type) {
    case 'success': return 'text-green-500'
    case 'error': return 'text-red-500'
    case 'warning': return 'text-yellow-500'
    case 'info': return 'text-blue-500'
    default: return 'text-gray-500'
  }
})
</script>

<template>
  <div
    class="pointer-events-auto flex items-center gap-3 px-5 py-3 rounded-full bg-white shadow-xl border border-black/5 min-w-[280px] max-w-md animate-toast-in"
    :class="[`toast--${toast.type}`]"
    role="alert"
  >
    <div class="flex-shrink-0">
      <component 
        :is="iconComponent" 
        class="h-5 w-5" 
        :class="iconColorClass"
        aria-hidden="true" 
      />
    </div>
    <div class="flex-1 min-w-0">
      <p class="text-[14px] font-medium text-slate-800 truncate">
        {{ toast.message }}
      </p>
    </div>
    <div class="flex-shrink-0 ml-2">
      <button
        type="button"
        class="p-1 rounded-full hover:bg-slate-100 text-slate-400 hover:text-slate-600 transition-colors"
        @click="removeToast(toast.id)"
      >
        <X class="h-4 w-4" aria-hidden="true" />
      </button>
    </div>
  </div>
</template>

<style scoped>
.rounded-full {
  border-radius: var(--radius-xl);
}

.shadow-xl {
  box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.08), 0 8px 10px -6px rgba(0, 0, 0, 0.05);
}

.bg-white {
  background-color: var(--bg-surface);
}

.text-slate-800 {
  color: var(--text-primary);
}

.toast--success {
  background: linear-gradient(to right, #e6f4ea, var(--bg-surface) 60px);
}

.toast--error {
  background: linear-gradient(to right, #fff0f0, var(--bg-surface) 60px);
}

.toast--warning {
  background: linear-gradient(to right, #fef7e0, var(--bg-surface) 60px);
}

.toast--info {
  background: linear-gradient(to right, #e8f0fe, var(--bg-surface) 60px);
}

.animate-toast-in {
  animation: slideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1);
}

@keyframes slideIn {
  from {
    transform: translateY(-12px) scale(0.92);
    opacity: 0;
  }
  to {
    transform: translateY(0) scale(1);
    opacity: 1;
  }
}
</style>

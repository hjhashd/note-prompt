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
    class="pointer-events-auto flex w-full max-w-sm overflow-hidden rounded-lg border bg-white shadow-lg ring-1 ring-black ring-opacity-5 transition-all dark:bg-slate-800 dark:ring-white/10"
    :class="[
      // Optional: Add type-specific subtle backgrounds if desired, but clean white/dark is often better for modern look.
      // We will stick to clean design with colored icons.
    ]"
    role="alert"
  >
    <div class="p-4 w-full">
      <div class="flex items-start">
        <div class="flex-shrink-0">
          <component 
            :is="iconComponent" 
            class="h-5 w-5" 
            :class="iconColorClass"
            aria-hidden="true" 
          />
        </div>
        <div class="ml-3 w-0 flex-1 pt-0.5">
          <p class="text-sm font-medium text-gray-900 dark:text-gray-100">
            {{ toast.message }}
          </p>
        </div>
        <div class="ml-4 flex flex-shrink-0">
          <button
            type="button"
            class="inline-flex rounded-md bg-transparent text-gray-400 hover:text-gray-500 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 dark:hover:text-gray-300"
            @click="removeToast(toast.id)"
          >
            <span class="sr-only">Close</span>
            <X class="h-4 w-4" aria-hidden="true" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

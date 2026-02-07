<script setup lang="ts">
import { ref, watch } from 'vue'
import { X, User, Calendar, Eye, Heart } from 'lucide-vue-next'
import CopyButton from '@/components/common/CopyButton.vue'
import { getPromptDetail, toggleFavorite } from '@/api/prompt'
import type { PromptItem } from '@/types/prompt'

const props = defineProps<{
  visible: boolean
  promptId: number | null
  initialData?: PromptItem | null
}>()

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void
  (e: 'update', value: PromptItem): void
}>()

const prompt = ref<PromptItem | null>(null)
const loading = ref(false)
const togglingFavorite = ref(false)

const close = () => {
  emit('update:visible', false)
}

const handleToggleFavorite = async () => {
  if (!prompt.value || !props.promptId || togglingFavorite.value) return
  
  togglingFavorite.value = true
  try {
    const newStatus = await toggleFavorite(props.promptId)
    prompt.value.isFavorited = newStatus
    const currentFavs = prompt.value.stats.favorites || 0
    prompt.value.stats.favorites = currentFavs + (newStatus ? 1 : -1)
    
    // Emit update to parent
    emit('update', prompt.value)
  } catch (error) {
    console.error('Failed to toggle favorite:', error)
  } finally {
    togglingFavorite.value = false
  }
}

const startTime = ref(0)

watch(() => props.visible, async (newVal) => {
  if (newVal && props.promptId) {
    startTime.value = performance.now()
    
    // Use initial data immediately for instant response
    if (props.initialData && props.initialData.id === props.promptId) {
      prompt.value = props.initialData
      loading.value = false
    } else {
      loading.value = true
    }

    try {
      const res = await getPromptDetail(props.promptId)
      
      // Calculate FCP-like metric for modal
      const endTime = performance.now()
      const duration = endTime - startTime.value
      console.log(`Modal Content Ready: ${duration.toFixed(2)}ms`)

      prompt.value = res
      // View count is incremented on backend fetch, so we emit the update immediately
      emit('update', res)
    } catch (error) {
      console.error('Failed to fetch prompt detail:', error)
    } finally {
      loading.value = false
    }
  } else {
    // Clear data when closing, but maybe delay slightly for animation?
    if (!newVal) {
      setTimeout(() => {
        prompt.value = null
      }, 300)
    }
  }
})

const getTagTone = (tag: string) => {
  const t = tag.toLowerCase()

  const tech = ['python', 'vue', 'typescript', 'sql', 'pandas', 'web', '前端', '后端', '数据库', '数据', '开发']
  const writing = ['写作', '文案', '周报', '办公', '邮件', '报告', '效率']
  const creative = ['ai绘画', 'midjourney', '设计', '创意', '故事', '绘画']
  const business = ['商业', '运营', '营销', '产品', '增长']

  if (tech.some((k) => t.includes(k))) return 'tag--blue'
  if (writing.some((k) => t.includes(k))) return 'tag--purple'
  if (creative.some((k) => t.includes(k))) return 'tag--amber'
  if (business.some((k) => t.includes(k))) return 'tag--emerald'
  return 'tag--gray'
}
</script>

<template>
  <Transition name="modal-fade">
    <div v-if="visible" class="modal-overlay" @click="close">
      <div class="modal-container" @click.stop>
        <button class="close-btn" @click="close">
          <X :size="20" />
        </button>

        <div v-if="loading" class="loading-state">
          加载中...
        </div>

        <div v-else-if="prompt" class="modal-content">
          <div class="modal-header">
            <h2 class="prompt-title">{{ prompt.title }}</h2>
            <div class="prompt-meta">
              <div class="author">
                <div class="avatar">
                  <img v-if="prompt.author.avatar" :src="prompt.author.avatar" alt="">
                  <User v-else :size="14" />
                </div>
                <span class="author-name">{{ prompt.author.name }}</span>
              </div>
              <div class="date">
                <Calendar :size="14" />
                <span>{{ prompt.updatedAt }}</span>
              </div>
            </div>
          </div>

          <div class="prompt-tags">
            <span v-for="tag in prompt.tags" :key="tag" class="tag" :class="getTagTone(tag)">
              {{ tag }}
            </span>
          </div>

          <div class="prompt-stats">
            <div class="stat">
              <Eye :size="16" />
              <span>{{ prompt.stats.views }} 浏览</span>
            </div>
            <div 
              class="stat interactive" 
              :class="{ 'is-active': prompt.isFavorited }"
              @click="handleToggleFavorite"
            >
              <Heart 
                :size="16" 
                :fill="prompt.isFavorited ? 'currentColor' : 'none'" 
                :class="{ 'animate-bounce': togglingFavorite }"
              />
              <span>{{ prompt.stats.favorites || 0 }} 收藏</span>
            </div>
          </div>

          <div class="content-section">
            <div class="section-header">
              <h3>提示词内容</h3>
              <CopyButton :text="prompt.content || ''" />
            </div>
            <div class="prompt-code">
              {{ prompt.content }}
            </div>
          </div>

          <div v-if="prompt.description" class="desc-section">
            <h3>描述</h3>
            <p>{{ prompt.description }}</p>
          </div>
        </div>
      </div>
    </div>
  </Transition>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.12);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
  backdrop-filter: blur(4px);
  will-change: opacity;
}

.modal-container {
  background: white;
  width: 90%;
  max-width: 800px;
  max-height: 90vh;
  border-radius: 8px;
  box-shadow: 0 24px 48px rgba(0, 0, 0, 0.18);
  position: relative;
  overflow-y: auto;
  display: flex;
  flex-direction: column;
  will-change: transform, opacity;
}

.close-btn {
  position: absolute;
  top: 16px;
  right: 16px;
  padding: 8px;
  border-radius: 50%;
  border: none;
  background: transparent;
  cursor: pointer;
  color: #64748b;
  z-index: 10;
}

.close-btn:hover {
  background: #f1f5f9;
  color: #0f172a;
}

.modal-content {
  padding: 32px;
}

.prompt-title {
  font-size: 24px;
  font-weight: 700;
  color: #0f172a;
  margin-bottom: 16px;
}

.prompt-meta {
  display: flex;
  gap: 24px;
  color: #64748b;
  font-size: 14px;
  margin-bottom: 24px;
}

.author, .date {
  display: flex;
  align-items: center;
  gap: 8px;
}

.avatar {
  width: 24px;
  height: 24px;
  border-radius: 50%;
  background: #f1f5f9;
  display: flex;
  align-items: center;
  justify-content: center;
  overflow: hidden;
}

.avatar img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.prompt-tags {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-bottom: 24px;
}

.tag {
  font-size: 11px;
  color: var(--gray-700);
  background: var(--gray-100);
  padding: 2px 8px;
  border-radius: 100px;
  font-weight: 500;
  border: 1px solid rgba(15, 23, 42, 0.06);
}

.tag--blue {
  color: #1d4ed8;
  background: #eff6ff;
  border-color: rgba(29, 78, 216, 0.18);
}

.tag--purple {
  color: #6d28d9;
  background: #f5f3ff;
  border-color: rgba(109, 40, 217, 0.18);
}

.tag--amber {
  color: #b45309;
  background: #fffbeb;
  border-color: rgba(180, 83, 9, 0.18);
}

.tag--emerald {
  color: #047857;
  background: #ecfdf5;
  border-color: rgba(4, 120, 87, 0.18);
}

.tag--gray {
  color: var(--gray-600);
  background: var(--gray-100);
  border-color: rgba(15, 23, 42, 0.06);
}

.prompt-stats {
  display: flex;
  gap: 24px;
  padding: 16px 0;
  border-top: 1px solid #e2e8f0;
  border-bottom: 1px solid #e2e8f0;
  margin-bottom: 24px;
  color: #64748b;
  font-size: 14px;
}

.stat {
  display: flex;
  align-items: center;
  gap: 8px;
}

.stat.interactive {
  cursor: pointer;
  transition: all 0.2s ease;
  padding: 4px 8px;
  border-radius: 6px;
  margin: -4px -8px;
}

.stat.interactive:hover {
  background: #fee2e2;
  color: #ef4444;
}

.stat.interactive.is-active {
  color: #ef4444;
}

.stat.interactive.is-active svg {
  transform: scale(1.1);
}

.animate-bounce {
  animation: bounce 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
}

@keyframes bounce {
  0% { transform: scale(1); }
  50% { transform: scale(1.3); }
  100% { transform: scale(1); }
}

.content-section {
  margin-bottom: 24px;
}

.section-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.section-header h3 {
  font-size: 16px;
  font-weight: 600;
  color: #334155;
  margin: 0;
}

.prompt-code {
  background: #f8fafc;
  padding: 20px;
  border-radius: 12px;
  border: 1px solid #e2e8f0;
  font-family: monospace;
  white-space: pre-wrap;
  color: #334155;
  line-height: 1.6;
  font-size: 14px;
}

.desc-section h3 {
  font-size: 16px;
  font-weight: 600;
  color: #334155;
  margin-bottom: 8px;
}

.desc-section p {
  color: #475569;
  line-height: 1.6;
}

.loading-state {
  padding: 60px;
  text-align: center;
  color: #64748b;
}

/* Transitions */
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: opacity 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-active .modal-container,
.modal-fade-leave-active .modal-container {
  transition: transform 0.25s cubic-bezier(0.4, 0, 0.2, 1);
}

.modal-fade-enter-from .modal-container,
.modal-fade-leave-to .modal-container {
  transform: translate3d(0, 20px, 0) scale(0.95);
}

@media (prefers-reduced-motion: reduce) {
  .modal-fade-enter-active,
  .modal-fade-leave-active,
  .modal-fade-enter-active .modal-container,
  .modal-fade-leave-active .modal-container {
    transition: none;
  }
}

:global(body.low-end-device) .modal-fade-enter-active,
:global(body.low-end-device) .modal-fade-leave-active,
:global(body.low-end-device) .modal-fade-enter-active .modal-container,
:global(body.low-end-device) .modal-fade-leave-active .modal-container {
  transition: none !important;
  animation: none !important;
}
</style>
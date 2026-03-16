import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import MyPromptsView from '../MyPromptsView.vue'

vi.mock('vue-router', () => ({
  useRouter: () => ({ push: vi.fn() }),
  onBeforeRouteLeave: vi.fn()
}))

vi.mock('@/stores/app', () => ({
  useAppStore: () => ({ isSidebarCollapsed: false })
}))

vi.mock('@/stores/chat', () => ({
  useChatStore: () => ({ openDraftSession: vi.fn() })
}))

vi.mock('@/stores/user', () => ({
  useUserStore: () => ({ userInfo: { id: 1, departmentId: 1 } })
}))

vi.mock('@/api/prompt', () => ({
  getPrompts: vi.fn().mockResolvedValue({
    list: [
      { id: 1, title: 'Prompt 1', tags: [], stats: {}, author: { id: 1, name: 'User' } },
      { id: 2, title: 'Prompt 2', tags: ['Vue'], stats: {}, author: { id: 1, name: 'User' } }
    ],
    total: 2
  }),
  batchSharePrompts: vi.fn()
}))

vi.mock('@/api/promptSave', () => ({
  getPythonTagsTree: vi.fn().mockResolvedValue({ personal_tags: [{ id: 10, tag_name: 'TestTag' }] }),
  addTagToPrompt: vi.fn(),
  removeTagFromPrompt: vi.fn(),
  deletePrompt: vi.fn()
}))

const mockToast = vi.fn()
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ toast: mockToast })
}))

// Mock ResizeObserver
global.ResizeObserver = class ResizeObserver {
  observe() {}
  unobserve() {}
  disconnect() {}
}

// Mock IntersectionObserver
global.IntersectionObserver = class IntersectionObserver {
  constructor() {}
  observe() {}
  unobserve() {}
  disconnect() {}
}

describe('MyPromptsView.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('handles batch tag addition with reactive updates', async () => {
    // mock scrollTo
    Element.prototype.scrollTo = () => {}

    const wrapper = mount(MyPromptsView, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          TiledCategoryFilter: true,
          TagManageModal: true
        }
      }
    })

    await flushPromises()
    
    // Simulate selecting a prompt (Prompt 1)
    const promptList = wrapper.findComponent({ name: 'PromptList' })
    promptList.vm.prompts = [
      { id: 1, title: 'Prompt 1', tags: [], stats: {}, author: { id: 1, name: 'User' } }
    ]
    
    // Enter batch tag mode
    const enterBatchTagBtn = wrapper.findAll('.btn-secondary').find(b => b.text().includes('批量管理标签'))
    if (enterBatchTagBtn) await enterBatchTagBtn.trigger('click')
    
    // Select prompt 1
    wrapper.vm.selectedPrompts.add(1)
    await wrapper.vm.$nextTick()
    
    // Open modal
    const manageTagBtn = wrapper.findAll('.btn-primary').find(b => b.text().includes('管理标签'))
    if (manageTagBtn) await manageTagBtn.trigger('click')
    await flushPromises()
    
    // Select tag and submit
    wrapper.vm.batchTagSelected = 10 // TestTag id
    wrapper.vm.batchTagMode = 'add'
    await wrapper.vm.$nextTick()
    
    await wrapper.vm.executeBatchAddTag()
    await flushPromises()
    
    // Check if tag was added reactively without reloading
    expect(promptList.vm.prompts[0].tags).toContain('TestTag')
    expect(mockToast).toHaveBeenCalledWith('成功为 1 个提示词添加标签「TestTag」', 'success')
  })

  it('handles network error during batch processing and rolls back/notifies user', async () => {
    const { addTagToPrompt } = await import('@/api/promptSave')
    vi.mocked(addTagToPrompt).mockRejectedValueOnce(new Error('Network Error'))
    
    // mock scrollTo
    Element.prototype.scrollTo = () => {}
    
    const wrapper = mount(MyPromptsView, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          TiledCategoryFilter: true,
          TagManageModal: true
        }
      }
    })

    await flushPromises()
    
    const promptList = wrapper.findComponent({ name: 'PromptList' })
    promptList.vm.prompts = [
      { id: 1, title: 'Prompt 1', tags: [], stats: {}, author: { id: 1, name: 'User' } }
    ]
    
    wrapper.vm.isBatchTagMode = true
    wrapper.vm.selectedPrompts.add(1)
    wrapper.vm.userTags = [{ id: 10, tag_name: 'TestTag' }]
    wrapper.vm.batchTagSelected = 10
    
    await wrapper.vm.executeBatchAddTag()
    await flushPromises()
    
    // Check if error is handled
    expect(mockToast).toHaveBeenCalledWith('批量添加标签失败', 'error')
    expect(promptList.vm.prompts[0].tags).not.toContain('TestTag')
  })
})

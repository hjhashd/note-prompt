import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import AiContentRenderer from '../AiContentRenderer.vue'
import ThinkBlock from '../ThinkBlock.vue'

// Mock ThinkBlock component to intercept method calls
const MockThinkBlock = {
  name: 'ThinkBlock',
  template: '<div class="think-block"><slot /></div>',
  props: ['content'],
  methods: {
    collapse: vi.fn()
  },
  expose: ['collapse']
}

describe('AiContentRenderer.vue', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('renders thinking content correctly', () => {
    const wrapper = mount(AiContentRenderer, {
      props: {
        content: '<think>This is thinking process</think>This is the answer',
        isStreaming: false
      },
      global: {
        stubs: {
          ThinkBlock: true // Use default stub or we can use our MockThinkBlock if we need to check methods
        }
      }
    })

    const thinkBlock = wrapper.findComponent(ThinkBlock)
    expect(thinkBlock.exists()).toBe(true)
    expect(thinkBlock.props('content')).toBe('This is thinking process')
  })

  it('renders markdown answer correctly', () => {
    const wrapper = mount(AiContentRenderer, {
      props: {
        content: '<think>Thinking</think>**Bold Answer**',
        isStreaming: false
      }
    })

    const markdownBody = wrapper.find('.markdown-body')
    expect(markdownBody.exists()).toBe(true)
    expect(markdownBody.html()).toContain('<strong>Bold Answer</strong>')
  })

  it('shows loading state when content is empty and streaming', () => {
    const wrapper = mount(AiContentRenderer, {
      props: {
        content: '',
        isStreaming: true
      }
    })

    expect(wrapper.find('.loading-state').exists()).toBe(true)
    expect(wrapper.text()).toContain('AI 正在思考中...')
  })

  it('emits stream-end and triggers collapse after delay when streaming stops', async () => {
    // We need to use a component stub that actually exposes the collapse method
    // or use shallowMount with a spy on the ref?
    // In Vue Test Utils with script setup, accessing exposed methods on stubs can be tricky.
    // However, if we mount full, ThinkBlock is a real child.
    // Let's use a mock implementation for ThinkBlock to avoid its internal logic dependency.
    
    // We can spy on the component instance method if we use the real component
    // But ThinkBlock might have its own logic. 
    // Let's rely on the fact that AiContentRenderer calls `collapse()` on the ref.
    
    const collapseSpy = vi.fn()
    
    const wrapper = mount(AiContentRenderer, {
      props: {
        content: '<think>Thinking</think>Answer',
        isStreaming: true
      },
      global: {
        stubs: {
          ThinkBlock: {
            template: '<div></div>',
            methods: {
              collapse: collapseSpy
            },
            expose: ['collapse']
          },
          CopyButton: true
        }
      }
    })

    // Simulate stream end
    await wrapper.setProps({ isStreaming: false })
    
    // Check emit
    expect(wrapper.emitted('stream-end')).toBeTruthy()
    
    // Should not collapse immediately
    expect(collapseSpy).not.toHaveBeenCalled()
    
    // Fast forward time by 200ms
    vi.advanceTimersByTime(200)
    
    // Wait for next tick/promises
    await wrapper.vm.$nextTick()
    
    // Check collapse called
    expect(collapseSpy).toHaveBeenCalled()
  })
})

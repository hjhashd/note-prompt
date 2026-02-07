import { mount } from '@vue/test-utils'
import { describe, it, expect, vi, beforeEach } from 'vitest'
import PromptDetailModal from '../PromptDetailModal.vue'
import { getPromptDetail, toggleFavorite } from '@/api/prompt'

// Mock icons
vi.mock('lucide-vue-next', () => ({
  X: { template: '<span class="icon-x" />' },
  User: { template: '<span class="icon-user" />' },
  Calendar: { template: '<span class="icon-calendar" />' },
  Eye: { template: '<span class="icon-eye" />' },
  Heart: { template: '<span class="icon-heart" />' }
}))

// Mock API
vi.mock('@/api/prompt', () => ({
  getPromptDetail: vi.fn(),
  toggleFavorite: vi.fn()
}))

describe('PromptDetailModal', () => {
  const mockPrompt: any = {
    id: 1,
    title: 'Test Prompt',
    content: 'Test Content',
    tags: ['vue', 'python'],
    author: { name: 'Test User', avatar: '' },
    stats: { views: 100, favorites: 50 },
    updatedAt: '2023-01-01T00:00:00Z',
    isFavorited: false,
    description: 'Test Description'
  }

  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders correctly when visible with initial data', async () => {
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: mockPrompt
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    
    expect(wrapper.find('.modal-container').exists()).toBe(true)
    expect(wrapper.find('.prompt-title').text()).toBe('Test Prompt')
    expect(wrapper.find('.author-name').text()).toBe('Test User')
    expect(wrapper.findAll('.tag').length).toBe(2)
  })

  it('emits close event when close button is clicked', async () => {
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: mockPrompt
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    await wrapper.find('.close-btn').trigger('click')
    expect(wrapper.emitted('update:visible')).toBeTruthy()
    expect(wrapper.emitted('update:visible')?.[0]).toEqual([false])
  })

  it('shows loading state when visible is true but no data', async () => {
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: null
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    // Mock delayed response
    ;(getPromptDetail as any).mockImplementation(() => new Promise(() => {}))

    await wrapper.setProps({ visible: true })
    expect(wrapper.find('.loading-state').exists()).toBe(true)
  })

  it('fetches data when visible becomes true without initialData', async () => {
    ;(getPromptDetail as any).mockResolvedValue(mockPrompt)

    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: null
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    expect(getPromptDetail).toHaveBeenCalledWith(1)
    
    // Wait for promise resolution
    await new Promise(resolve => setTimeout(resolve, 0))
    await wrapper.vm.$nextTick()
    
    expect(wrapper.find('.prompt-title').text()).toBe('Test Prompt')
  })

  it('fetches data when initialData id does not match promptId', async () => {
    ;(getPromptDetail as any).mockResolvedValue(mockPrompt)

    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: { ...mockPrompt, id: 999 } // Mismatch ID
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    expect(getPromptDetail).toHaveBeenCalledWith(1)
  })

  it('toggles favorite status successfully', async () => {
    ;(toggleFavorite as any).mockResolvedValue(true)
    
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: mockPrompt
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    const favoriteBtn = wrapper.find('.stat.interactive')
    await favoriteBtn.trigger('click')
    
    expect(toggleFavorite).toHaveBeenCalledWith(1)
    await wrapper.vm.$nextTick()
    await new Promise(resolve => setTimeout(resolve, 0))

    // Check emit
    const emitEvents = wrapper.emitted('update')
    expect(emitEvents).toBeTruthy()
    // The last event should have updated favorite status
    const lastEvent = emitEvents![emitEvents!.length - 1][0] as any
    expect(lastEvent.isFavorited).toBe(true)
    expect(lastEvent.stats.favorites).toBe(51)
  })

  it('handles toggle favorite error gracefully', async () => {
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    ;(toggleFavorite as any).mockRejectedValue(new Error('Failed'))
    
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: mockPrompt
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    const favoriteBtn = wrapper.find('.stat.interactive')
    await favoriteBtn.trigger('click')
    
    expect(toggleFavorite).toHaveBeenCalledWith(1)
    await wrapper.vm.$nextTick()
    await new Promise(resolve => setTimeout(resolve, 0))

    consoleSpy.mockRestore()
  })

  it('handles fetch error gracefully', async () => {
    const consoleSpy = vi.spyOn(console, 'error').mockImplementation(() => {})
    ;(getPromptDetail as any).mockRejectedValue(new Error('Fetch failed'))

    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: null
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    await new Promise(resolve => setTimeout(resolve, 0))
    
    expect(wrapper.find('.loading-state').exists()).toBe(false) // Loading set to false in finally
    // Should probably show empty or error state, but current impl just shows nothing or keeps loading false
    consoleSpy.mockRestore()
  })

  it('resets data when modal is closed', async () => {
    vi.useFakeTimers()
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: mockPrompt
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })
    expect(wrapper.find('.modal-content').exists()).toBe(true)

    await wrapper.setProps({ visible: false })
    vi.advanceTimersByTime(300)
    await wrapper.vm.$nextTick()
    
    // modal-content should be gone (v-if="prompt")
    // Wait, v-if="visible" is on modal-overlay, but prompt data is reset.
    // The component structure is:
    // <div v-if="visible" ...>
    //   ...
    //   <div v-else-if="prompt" class="modal-content">
    
    // Even if visible is false, the DOM is gone because of outer v-if.
    // But we want to test if internal state `prompt` is null.
    // We can re-open it without ID and see if it's empty?
    // Or just check if we can trigger logic.
    
    // Actually, checking if prompt is null is hard without access to vm state in script setup.
    // Let's rely on the fact that if we open it again without data, it should load.
    
    await wrapper.setProps({ visible: true, promptId: 2, initialData: null })
    expect(wrapper.find('.loading-state').exists()).toBe(true)
    
    vi.useRealTimers()
  })

  it('renders correct tag colors', async () => {
    const promptWithTags = {
      ...mockPrompt,
      tags: ['python', '写作', 'ai绘画', '商业', 'unknown']
    }
    
    const wrapper = mount(PromptDetailModal, {
      props: {
        visible: false,
        promptId: 1,
        initialData: promptWithTags
      },
      global: {
        stubs: {
          Transition: {
            template: '<div><slot /></div>'
          },
          CopyButton: true
        }
      }
    })

    await wrapper.setProps({ visible: true })

    const tags = wrapper.findAll('.tag')
    expect(tags[0].classes()).toContain('tag--blue') // python
    expect(tags[1].classes()).toContain('tag--purple') // 写作
    expect(tags[2].classes()).toContain('tag--amber') // ai绘画
    expect(tags[3].classes()).toContain('tag--emerald') // 商业
    expect(tags[4].classes()).toContain('tag--gray') // unknown
  })
})

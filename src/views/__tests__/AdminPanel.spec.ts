import { describe, it, expect, vi, beforeEach } from 'vitest'
import { mount, flushPromises } from '@vue/test-utils'
import AdminPanel from '../AdminPanel.vue'
import * as adminApi from '@/api/admin'
import * as useToastModule from '@/composables/useToast'

vi.mock('@/api/admin', () => ({
  getSystemStats: vi.fn().mockResolvedValue({
    total_users: 100, total_prompts: 50, total_likes: 20, total_uses: 10,
    total_favorites: 5, total_shares: 2, total_views: 200, active_users_today: 10, new_prompts_today: 5
  }),
  getTopUsers: vi.fn().mockResolvedValue([]),
  getTopPrompts: vi.fn().mockResolvedValue([]),
  getUsersList: vi.fn().mockImplementation(() => Promise.resolve({
    list: [
      { id: 1, name: 'User 1', department_name: 'IT', role: 'admin', prompt_count: 5, status: 'Active', join_date: '2023-01-01' },
      { id: 2, name: 'User 2', department_name: 'HR', role: 'user', prompt_count: 2, status: 'Inactive', join_date: '2023-01-02' }
    ],
    page: 1, page_size: 10, total: 2, total_pages: 1
  })),
  updateUserStatus: vi.fn()
}))

const mockToast = vi.fn()
vi.mock('@/composables/useToast', () => ({
  useToast: () => ({ toast: mockToast })
}))

describe('AdminPanel.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('renders users list and handles status toggle without full reload', async () => {
    const wrapper = mount(AdminPanel, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          UserFormModal: true,
          ResetPasswordModal: true,
          component: true
        }
      }
    })

    await flushPromises()

    const rows = wrapper.findAll('tbody tr')
    expect(rows.length).toBe(2)

    let toggleBtn1 = wrapper.findAll('tbody tr')[0].findAll('.action-btn')[3]
    expect(toggleBtn1.attributes('title')).toBe('禁用用户')
    expect(toggleBtn1.classes()).toContain('danger')

    await toggleBtn1.trigger('click')
    await flushPromises()

    expect(adminApi.updateUserStatus).toHaveBeenCalledWith(1, 0)
    expect(mockToast).toHaveBeenCalledWith('用户禁用成功', 'success')
    
    toggleBtn1 = wrapper.findAll('tbody tr')[0].findAll('.action-btn')[3]
    expect(toggleBtn1.attributes('title')).toBe('启用用户')
    expect(toggleBtn1.classes()).toContain('success')
  })

  it('handles search input with debounce', async () => {
    vi.useFakeTimers()
    const wrapper = mount(AdminPanel, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          UserFormModal: true,
          ResetPasswordModal: true,
          component: true
        }
      }
    })

    await flushPromises()
    vi.clearAllMocks()

    const searchInput = wrapper.find('.search-box input')
    
    // Simulate user typing
    await searchInput.setValue('test user')
    await searchInput.trigger('input')
    
    // Search should not be called immediately
    expect(adminApi.getUsersList).not.toHaveBeenCalled()
    
    // Fast forward time by 200ms
    vi.advanceTimersByTime(200)
    expect(adminApi.getUsersList).not.toHaveBeenCalled()
    
    // Fast forward time to exceed 300ms debounce
    vi.advanceTimersByTime(150)
    
    expect(adminApi.getUsersList).toHaveBeenCalledTimes(1)
    expect(adminApi.getUsersList).toHaveBeenCalledWith(expect.objectContaining({
      keyword: 'test user',
      page: 1
    }))
    
    vi.useRealTimers()
  })

  it('shows loading overlay during page change without clearing rows', async () => {
    const wrapper = mount(AdminPanel, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          UserFormModal: true,
          ResetPasswordModal: true,
          component: true
        }
      }
    })

    await flushPromises()

    const vm = wrapper.vm as any
    vm.usersList = [
      { id: 1, name: 'User 1', department_name: 'IT', role: 'admin', prompt_count: 5, status: 'Active', join_date: '2023-01-01' }
    ]
    vm.loading.users = true
    await wrapper.vm.$nextTick()

    expect(wrapper.find('.table-loading-overlay').exists()).toBe(true)
    expect(wrapper.findAll('tbody tr').length).toBeGreaterThan(0)
  })

  it('handles status toggle error and rollbacks', async () => {
    vi.mocked(adminApi.updateUserStatus).mockRejectedValueOnce(new Error('API Error'))
    
    const wrapper = mount(AdminPanel, {
      global: {
        stubs: {
          'lucide-vue-next': true,
          UserFormModal: true,
          ResetPasswordModal: true,
          component: true
        }
      }
    })

    await flushPromises()

    let toggleBtn1 = wrapper.findAll('tbody tr')[0].findAll('.action-btn')[3]
    
    await toggleBtn1.trigger('click')
    await flushPromises()

    expect(mockToast).toHaveBeenCalledWith('操作失败 (点击重试)', 'error')
    
    toggleBtn1 = wrapper.findAll('tbody tr')[0].findAll('.action-btn')[3]
    expect(toggleBtn1.attributes('title')).toBe('禁用用户')
    expect(toggleBtn1.classes()).toContain('danger')
  })
})

# 提示词系统开发指南 (Client Side)

本文档适用于 **提示词系统 (Prompt System)** 的开发人员。
它定义了新系统的技术栈规范、通信协议以及如何与宿主环境（报告系统）进行交互。

## 1. 技术栈规范 (Tech Stack)

为了确保系统的高性能、可维护性及现代化的开发体验，本项目**必须**采用以下技术栈：

*   **Core Framework**: [Vue 3](https://vuejs.org/) (Composition API + `<script setup>`)
*   **Build Tool**: [Vite](https://vitejs.dev/) (极速冷启动)
*   **State Management**: [Pinia](https://pinia.vuejs.org/) (轻量级状态管理)
*   **Styling**: [Tailwind CSS](https://tailwindcss.com/) (原子化 CSS)
*   **Language**: [TypeScript](https://www.typescriptlang.org/) (强类型约束)

### 1.1 为什么选择 Tailwind CSS？
*   **样式隔离**: 虽然我们将运行在 Iframe 中，天然隔离了 CSS，但 Tailwind 的 Utility-first 理念能极大减少自定义 CSS 的编写，保持代码库整洁。
*   **开发效率**: 配合 VS Code 插件，无需在 template 和 style 标签间来回跳转。
*   **一致性**: 强制使用设计系统的颜色和间距变量（需要在 `tailwind.config.js` 中配置公司的主题色）。

## 2. 核心基础设施：通信桥 (SmartBridge)

为了与宿主系统（老系统）通信，请将以下代码复制到 `src/utils/bridge.ts`。

```typescript
// src/utils/bridge.ts

export interface BridgeResponse<T = any> {
  success: boolean;
  data?: T;
  error?: string;
}

export class SmartBridge {
  private listeners = new Map<string, Function>();
  private targetWindow: Window;
  private targetOrigin: string;

  constructor(targetWindow = window.parent, targetOrigin = '*') {
    this.targetWindow = targetWindow;
    this.targetOrigin = targetOrigin;
    window.addEventListener('message', this._handleMessage.bind(this));
  }

  /**
   * 调用宿主系统的方法
   * @example await bridge.call('APPLY_PROMPT', { content: '...' })
   */
  call<T = any>(action: string, data?: any, timeout = 5000): Promise<T> {
    // 如果不在 iframe 中（独立开发模式），直接返回模拟数据
    if (window === window.parent) {
      console.warn(`[Dev] Bridge call simulated: ${action}`, data);
      return Promise.resolve({} as T);
    }

    const messageId = Date.now() + Math.random().toString(36).substr(2, 9);
    
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.listeners.delete(messageId);
        reject(new Error(`Bridge request timeout: ${action}`));
      }, timeout);

      this.listeners.set(messageId, (response: BridgeResponse<T>) => {
        clearTimeout(timer);
        if (response.success) resolve(response.data as T);
        else reject(new Error(response.error));
      });

      this.targetWindow.postMessage({
        type: 'BRIDGE_REQUEST',
        id: messageId,
        action,
        data
      }, this.targetOrigin);
    });
  }

  /**
   * 注册供宿主系统调用的方法
   */
  on(action: string, callback: (data: any) => Promise<any> | any) {
    this.listeners.set(`ACTION_${action}`, callback);
  }

  off(action: string) {
    this.listeners.delete(`ACTION_${action}`);
  }

  private async _handleMessage(event: MessageEvent) {
    const { type, id, action, data, success, error } = event.data || {};

    if (type === 'BRIDGE_REQUEST') {
      const handler = this.listeners.get(`ACTION_${action}`);
      if (handler) {
        try {
          const resData = await handler(data);
          event.source?.postMessage({
            type: 'BRIDGE_RESPONSE',
            id,
            success: true,
            data: resData
          }, event.origin);
        } catch (err: any) {
          event.source?.postMessage({
            type: 'BRIDGE_RESPONSE',
            id,
            success: false,
            error: err.message || 'Unknown error'
          }, event.origin);
        }
      }
    } else if (type === 'BRIDGE_RESPONSE') {
      const resolver = this.listeners.get(id);
      if (resolver) {
        resolver({ success, data, error });
        this.listeners.delete(id);
      }
    }
  }
}

export const bridge = new SmartBridge();
```

## 3. 业务开发流程

### 3.1 身份认证 (Authentication)
不要实现登录页！
在 `App.vue` 或 `main.ts` 中：
```typescript
// 解析 URL 参数中的 Token
const urlParams = new URLSearchParams(window.location.search);
const token = urlParams.get('token');

if (token) {
  // 存入 Pinia 或 localStorage
  userStore.setToken(token);
} else {
  // 开发环境可能没有 token，可以 mock 一个
  if (import.meta.env.DEV) {
    userStore.setToken('mock-dev-token');
  } else {
    // 生产环境没有 token 则报错
    showError('无法获取身份信息，请从报告系统进入');
  }
}
```

### 3.2 应用提示词 (Apply Prompt)
当用户点击“应用”按钮时：

```typescript
import { bridge } from '@/utils/bridge';

const handleApply = async (promptContent: string) => {
  try {
    loading.value = true;
    // 调用宿主能力
    await bridge.call('APPLY_PROMPT', { 
      content: promptContent,
      id: props.promptId 
    });
    
    // 如果没报错，说明宿主系统已经处理成功
    showToast('应用成功');
    // 可选：更新本地状态，标记该提示词已使用
    await api.markAsUsed(props.promptId);
  } catch (err) {
    showToast('应用失败: ' + err.message);
  } finally {
    loading.value = false;
  }
};
```

## 4. 样式规范 (Tailwind)

请在 `tailwind.config.js` 中配置与主系统相近的主题色，以保持视觉协调（虽然风格不同，但色相一致会更舒服）：

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: '#1890ff', // Ant Design Blue
        success: '#52c41a',
        warning: '#faad14',
        error: '#f5222d',
      }
    }
  }
}
```

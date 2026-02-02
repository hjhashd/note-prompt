
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
          const target = event.source as Window;
          target?.postMessage({
            type: 'BRIDGE_RESPONSE',
            id,
            success: true,
            data: resData
          }, event.origin);
        } catch (err: any) {
          const target = event.source as Window;
          target?.postMessage({
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

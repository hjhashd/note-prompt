/**
 * 复制文本到剪贴板
 * 兼容处理：优先使用 navigator.clipboard，如果不可用（如非 HTTPS 环境）则回退到 document.execCommand
 */
export async function copyToClipboard(text: string): Promise<boolean> {
  // 1. 尝试使用现代 API
  if (navigator.clipboard && window.isSecureContext) {
    try {
      await navigator.clipboard.writeText(text);
      return true;
    } catch (err) {
      console.error('navigator.clipboard copy failed:', err);
      // 继续尝试回退方案
    }
  }

  // 2. 回退方案：使用隐藏的 textarea + document.execCommand('copy')
  try {
    const textArea = document.createElement('textarea');
    textArea.value = text;
    
    // 确保 textarea 在移动端和各种浏览器中不可见，但能被选中
    textArea.style.position = 'fixed';
    textArea.style.left = '-9999px';
    textArea.style.top = '0';
    textArea.style.opacity = '0';
    document.body.appendChild(textArea);
    
    textArea.focus();
    textArea.select();
    
    const successful = document.execCommand('copy');
    document.body.removeChild(textArea);
    
    if (successful) {
      return true;
    }
  } catch (err) {
    console.error('Fallback copy failed:', err);
  }

  return false;
}

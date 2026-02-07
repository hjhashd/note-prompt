import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

// https://vite.dev/config/
export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  server: {
    proxy: {
      // Python 后端代理
      '/api/python': {
        target: process.env.VITE_PYTHON_API_URL || 'http://localhost:34521',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/python/, '/api')
      },
      // Java 后端代理
      '/api/java': {
        target: process.env.VITE_JAVA_API_URL || 'http://localhost:18081',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api\/java/, '/api')
      }
    }
  }
})

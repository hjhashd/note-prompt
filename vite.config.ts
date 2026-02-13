import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { compression } from 'vite-plugin-compression2'
import { fileURLToPath, URL } from 'node:url'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    vue(),
    {
      ...compression({
        threshold: 10240,
        algorithm: 'gzip',
        deleteOriginalAssets: false,
        skipIfLargerOrEqual: true,
      }),
      apply: 'build'
    }
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url))
    }
  },
  build: {
    target: 'esnext',
    minify: 'esbuild',
    chunkSizeWarningLimit: 1000,
    rollupOptions: {
      output: {
        manualChunks: {
          'vue-vendor': ['vue', 'vue-router', 'pinia', 'vue-virtual-scroller'],
          'ui-vendor': ['lucide-vue-next'],
          'markdown-vendor': ['markdown-it', 'github-markdown-css']
        }
      }
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

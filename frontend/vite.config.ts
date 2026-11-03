import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
  ],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8085',
        changeOrigin: true,
        timeout: 1800000,
        proxyTimeout: 1800000,
      },
      '/playback': {
        target: 'http://127.0.0.1:8085',
        changeOrigin: true,
      },
      '/thumbnails': {
        target: 'http://127.0.0.1:8085',
        changeOrigin: true,
      },
      '/logos': {
        target: 'http://127.0.0.1:8085',
        changeOrigin: true,
      },
      '/data': {
        target: 'http://127.0.0.1:8085',
        changeOrigin: true,
      },
    },
  },
})

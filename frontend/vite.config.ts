import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'
import { defineConfig } from 'vite'

const backendPort = process.env.BACKEND_PORT || '2085';
const backendTarget = `http://127.0.0.1:${backendPort}`;

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
        target: backendTarget,
        changeOrigin: true,
        timeout: 1800000,
        proxyTimeout: 1800000,
      },
      '/playback': {
        target: backendTarget,
        changeOrigin: true,
      },
      '/thumbnails': {
        target: backendTarget,
        changeOrigin: true,
      },
      '/logos': {
        target: backendTarget,
        changeOrigin: true,
      },
      '/data': {
        target: backendTarget,
        changeOrigin: true,
      },
    },
  },
})

import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'

// https://vite.dev/config/
export default defineConfig({
  base: './',
  plugins: [
    vue(),
    vueDevTools(),
  ],
  server: {
    proxy: {
      '/api/geo/ipwhois': {
        target: 'https://ipwho.is',
        changeOrigin: true,
        rewrite: function () {
          return '/'
        }
      },
      '/api/geo/ipsb': {
        target: 'https://api.ip.sb',
        changeOrigin: true,
        rewrite: function () {
          return '/geoip/'
        }
      },
      '/api/geo/vore': {
        target: 'https://api.vore.top',
        changeOrigin: true,
        rewrite: function () {
          return '/api/IPdata'
        }
      }
    }
  },
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})

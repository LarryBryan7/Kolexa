import path from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  // Build estático para Vercel (sin SSR, sin API routes).
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
});

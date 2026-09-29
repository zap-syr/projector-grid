import { svelte } from '@sveltejs/vite-plugin-svelte';
import { svelteTesting } from '@testing-library/svelte/vite';
import { defineConfig } from 'vitest/config';

import { mockApi } from './mocks/mockApi.ts';

export default defineConfig(({ mode }) => ({
  // `--mode mock` (npm run dev:mock) serves /api from mocks/ instead of the app.
  plugins: [svelte(), svelteTesting(), ...(mode === 'mock' ? [mockApi()] : [])],
  // Relative URLs, so index.html works whatever path the app serves it from.
  base: './',
  build: {
    // Bundled into the Flutter app as assets (see pubspec.yaml). Files from
    // public/ (the .gitkeep placeholders) are copied back on every build.
    outDir: '../assets/web',
    emptyOutDir: true,
    sourcemap: false,
  },
  server: {
    proxy:
      mode === 'mock'
        ? undefined
        : { '/api': { target: 'http://localhost:8080', changeOrigin: true } },
  },
  test: {
    environment: 'jsdom',
    include: ['tests/**/*.test.ts'],
  },
}));

import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/vite-plugin-svelte').SvelteConfig} */
export default {
  preprocess: vitePreprocess(),
  vitePlugin: {
    // Runes only in our own code; forcing it on node_modules would break
    // libraries that still ship legacy-mode components.
    dynamicCompileOptions({ filename }) {
      if (!filename.includes('node_modules')) return { runes: true };
    },
  },
};

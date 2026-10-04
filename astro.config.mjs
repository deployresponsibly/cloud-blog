import { defineConfig } from 'astro/config';

export default defineConfig({
  // Change this to your real domain before deploying (used for RSS and canonical links).
  site: 'https://deployresponsibly.com',
  markdown: {
    shikiConfig: { theme: 'nord' },
  },
});

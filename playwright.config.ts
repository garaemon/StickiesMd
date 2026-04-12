import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './test/e2e',
  timeout: 30000,
  retries: 1,
  use: {
    trace: 'on-first-retry',
  },
  reporter: [['list'], ['html', { open: 'never' }]],
});

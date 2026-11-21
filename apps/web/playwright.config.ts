import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  timeout: 60000, // Increase from 30s to 60s for slow dev compilation
  testDir: './tests',
  fullyParallel: false,
  retries: 0,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'on-first-retry',
  },
  projects: [
    { name: 'chromium', use: { ...devices['Desktop Chrome'] } },
  ],
});

import { test, expect } from '@playwright/test';

test.describe('Multilingual & Forecasting', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('User can change language to Telugu', async ({ page }) => {
    // Target the exact test ID
    await page.getByTestId('lang-select').selectOption('te');
    
    // Check if sidebar text updated to Telugu
    await expect(page.locator('text=అవలోకనం')).toBeVisible();
    await expect(page.locator('text=ఫిర్యాదుల క్యూ')).toBeVisible();
  });

  test('Forecast chart renders with actual and predicted data', async ({ page }) => {
    await page.goto('/intelligence');
    
    // Wait for ECharts canvas to render
    await expect(page.locator('canvas').first()).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Volume Forecast')).toBeVisible();
  });
});

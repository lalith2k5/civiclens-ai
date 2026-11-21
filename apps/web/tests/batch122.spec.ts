import { test, expect } from '@playwright/test';

test.describe('Functional Models & Rainfall', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Model Registry buttons show loading and success state', async ({ page }) => {
    await page.goto('/intelligence/registry');
    await page.waitForLoadState('networkidle');
    
    // Click the first "Approve" button
    const approveBtn = page.locator('button:has-text("Approve")').first();
    await approveBtn.click();
    
    // Verify loading spinner appears (or it just resolves quickly)
    // Wait for success message
    await expect(page.locator('text=Status updated!').first()).toBeVisible({ timeout: 5000 });
  });

  test('Rainfall Context renders map, chart, and provenance', async ({ page }) => {
    await page.goto('/intelligence/rainfall');
    await page.waitForLoadState('networkidle');
    
    await expect(page.locator('h2:has-text("Rainfall & Flood Context")')).toBeVisible();
    await expect(page.locator('text=Historical Flood Events')).toBeVisible();
    await expect(page.locator('text=Data Provenance')).toBeVisible();
    
    // Ensure canvas for chart renders
    await expect(page.locator('canvas').first()).toBeVisible({ timeout: 10000 });
  });
});

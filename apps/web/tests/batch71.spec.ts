import { test, expect } from '@playwright/test';

test.describe('Intelligence & Admin Gaps', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Geospatial Explorer renders with layer toggles', async ({ page }) => {
    await page.goto('/intelligence/explorer');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('h2:has-text("Geospatial Explorer")')).toBeVisible({ timeout: 15000 });
    await expect(page.locator('text=Open Reports')).toBeVisible();
    await expect(page.locator('text=Resolved Reports')).toBeVisible();
  });

  test('Admin can see Workflow and Workspace tabs', async ({ page }) => {
    await page.goto('/admin');
    await page.waitForLoadState('networkidle');
    
    await page.click('button:has-text("workflow")');
    await expect(page.locator('text=Status Transition Rules')).toBeVisible({ timeout: 5000 });
    
    await page.click('button:has-text("workspace")');
    await expect(page.locator('text=Workspace Settings')).toBeVisible({ timeout: 5000 });
  });

  test('Model Registry shows Approve/Disable buttons', async ({ page }) => {
    await page.goto('/intelligence/registry');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('text=Approve').first()).toBeVisible({ timeout: 10000 });
    await expect(page.locator('text=Disable').first()).toBeVisible();
  });
});

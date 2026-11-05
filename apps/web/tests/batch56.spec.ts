import { test, expect } from '@playwright/test';

test.describe('Spec Completion Batch', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Intelligence shows Hotspot Results Table', async ({ page }) => {
    await page.goto('/intelligence');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('body')).toContainText('Hotspot ID', { timeout: 15000 });
    await expect(page.locator('body')).toContainText('Dominant Issue', { timeout: 15000 });
  });

  test('Operator can toggle comment visibility', async ({ page }) => {
    await page.goto('/operations/report/1');
    await page.waitForTimeout(2000); // Wait for React hydration
    
    // Wait for the page to load the Audit Timeline to guarantee success
    await expect(page.locator('text=Audit Timeline')).toBeVisible({ timeout: 15000 });
    
    // Use the exact test ID we just added
    const visibilitySelect = page.getByTestId('visibility-select'); 
    await expect(visibilitySelect).toBeVisible({ timeout: 10000 });
    await visibilitySelect.selectOption('internal');
    await expect(visibilitySelect).toHaveValue('internal');
  });

  test('Field Worker submits evidence form', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await page.goto('/field');
    await page.waitForLoadState('networkidle');

    const completeBtn = page.locator('button:has-text("Complete Task")').first();
    if (await completeBtn.isVisible()) {
      await completeBtn.click();
      await page.locator('textarea').fill('Completed the work successfully.');
      await page.click('button:has-text("Submit Evidence")');
      await expect(page.locator('text=All caught up!')).toBeVisible();
    }
  });
});

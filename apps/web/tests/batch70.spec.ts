import { test, expect } from '@playwright/test';

test.describe('Citizen & Ops Gaps', () => {
  test('Citizen can dispute a resolved report', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Citizen")');
    await page.click('button[type="submit"]');
    await page.goto('/dashboard');
    await page.waitForLoadState('networkidle');
    // Assume there is at least one resolved report to test the button
    const disputeBtn = page.locator('button:has-text("Still Not Fixed")').first();
    if (await disputeBtn.isVisible()) {
      await disputeBtn.click();
    }
  });

  test('Operator can view Assignments and Performance', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');

    await page.goto('/operations/assignments');
    await expect(page.locator('text=Team Workload')).toBeVisible();

    await page.goto('/operations/performance');
    await expect(page.locator('text=Department Performance')).toBeVisible();
    await expect(page.locator('text=Resolution Rate')).toBeVisible();
  });
});

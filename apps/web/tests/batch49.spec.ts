import { test, expect } from '@playwright/test';

test.describe('Audit Timeline, Registry & Quality', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Operator can view Model Registry and Data Quality pages', async ({ page }) => {
    await page.click('text=Model Registry');
    await expect(page.locator('body')).toContainText('Image Classifier (MobileNetV3)');
    await expect(page.locator('body')).toContainText('98.02%');

    await page.click('text=Data Quality');
    await expect(page.locator('body')).toContainText('Overall Quality Score: 99.8%');
  });

  test('Report Detail shows Audit Timeline', async ({ page }) => {
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);
    
    // Check for timeline heading
    await expect(page.locator('text=Audit Timeline')).toBeVisible();
  });
});

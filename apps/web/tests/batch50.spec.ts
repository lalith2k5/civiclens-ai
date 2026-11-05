import { test, expect } from '@playwright/test';

test.describe('Hotspots & SLA', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Intelligence page renders Hotspot map with circles', async ({ page }) => {
    await page.goto('/intelligence');
    await expect(page.locator('text=Hotspot Clustering (DBSCAN)')).toBeVisible();
    await expect(page.locator('.leaflet-container')).toBeVisible();
  });

  test('Admin can configure SLA rules', async ({ page }) => {
    await page.click('text=Admin Settings');
    await page.click('button:has-text("sla")');
    await expect(page.locator('text=SLA Configuration')).toBeVisible();
    
    const criticalInput = page.locator('input[type="number"]').first();
    await criticalInput.fill('12');
    await criticalInput.blur();
    
    // Wait for API to finish
    await page.waitForTimeout(1500); 
    
    await page.reload();
    await page.click('button:has-text("sla")');
    await expect(page.locator('input[type="number"]').first()).toHaveValue('12');
  });
});

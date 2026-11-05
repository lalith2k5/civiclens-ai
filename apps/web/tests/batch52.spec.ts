import { test, expect } from '@playwright/test';

test.describe('Comments, Linking & Rainfall', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Operator can add comments and link duplicates', async ({ page }) => {
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);

    // 1. Add Comment
    await page.fill('input[placeholder="Add a public comment..."]', 'Playwright test comment');
    await page.click('button:has-text("Post")');
    await expect(page.locator('text=Playwright test comment')).toBeVisible();

    // 2. Link Duplicate
    await page.fill('input[placeholder="Parent Report ID"]', '1');
    await page.click('button:has-text("Link as Duplicate")');
    // Wait for timeline to update
    await page.waitForTimeout(1000);
    await expect(page.locator('text=Linked as duplicate of 1')).toBeVisible();
  });

  test('Intelligence page renders Rainfall context map', async ({ page }) => {
    await page.click('text=Rainfall Context');
    await expect(page.locator('text=Rainfall & Flood Context')).toBeVisible();
    await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });
  });
});

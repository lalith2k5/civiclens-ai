import { test, expect } from '@playwright/test';

test.describe('Profile, Categories & Bulk Actions', () => {
  test('Citizen can view Profile page', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Citizen")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*dashboard/);
    
    // CLICK THE SPECIFIC PROFILE LINK, NOT JUST THE FIRST BUTTON
    await page.locator('a[href="/profile"]').click();
    await expect(page).toHaveURL(/.*profile/);
    await expect(page.locator('text=Profile & Privacy')).toBeVisible();
  });

  test('Operator can perform Bulk Actions on Queue', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    
    await page.click('text=Complaint Queue');
    await page.locator('input[type="checkbox"]').nth(1).check();
    await page.locator('input[type="checkbox"]').nth(2).check();
    
    await expect(page.locator('text=2 selected')).toBeVisible();
    await page.click('button:has-text("Acknowledge")');
    await expect(page.locator('text=2 selected')).not.toBeVisible();
  });

  test('Admin can view Categories tab', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await page.click('text=Admin Settings');
    await page.click('button:has-text("categories")');
    await expect(page.locator('text=Manage Categories')).toBeVisible();
  });
});

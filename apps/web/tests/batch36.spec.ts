import { test, expect } from '@playwright/test';

test.describe('Field Worker Journey & Notifications', () => {

  test('Operator assigns task, Worker receives notification and resolves it', async ({ page }) => {
    // 1. Operator Logs in and assigns
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
    
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    await page.waitForURL(/.*operations\/report\/.*/);
    
    // WAIT FOR THE DROPDOWN TO APPEAR
    try {
      await page.waitForSelector('select', { timeout: 5000 });
    } catch (e) {
      console.log("PAGE CONTENT ON FAILURE:", await page.locator('body').innerText());
      throw e;
    }
    
    // Assign to first worker (Field Worker 1)
    await page.selectOption('select >> nth=0', { index: 1 });
    await page.click('button:has-text("Assign Worker")');
    await page.waitForTimeout(1000); 

    // 2. Field Worker Logs in
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*field/);

    // Worker sees task and resolves
    await expect(page.locator('body')).toContainText('My Assigned Tasks');
    const resolveBtn = page.locator('button:has-text("Mark Resolved")').first();
    await expect(resolveBtn).toBeVisible();
    
    // Handle prompt
    page.on('dialog', async dialog => {
      expect(dialog.message()).toContain('Enter completion notes');
      await dialog.accept('Fixed the pothole with new asphalt.');
    });
    await resolveBtn.click();
    
    await expect(page.locator('body')).toContainText('All caught up!');
  });
});

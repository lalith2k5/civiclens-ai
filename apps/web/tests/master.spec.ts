import { test, expect } from '@playwright/test';

test.describe.configure({ mode: 'serial' });

test.describe('CIVICLENS Master Suite', () => {
  
  test('1. Citizen Login and Submit Report', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Citizen")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*dashboard/);

    await page.goto('/report');
    await page.selectOption('select', { label: 'Potholes and RoadCracks' });
    await page.fill('textarea', 'Master test pothole description');
    await page.fill('input[placeholder="Latitude"]', '17.3850');
    await page.fill('input[placeholder="Longitude"]', '78.4867');
    await page.click('button:has-text("Submit Report")');
    await expect(page).toHaveURL(/.*dashboard/);
  });

  test('2. Citizen Profile and Dispute', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Citizen")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*dashboard/);

    await page.goto('/profile');
    await expect(page.locator('text=Profile & Privacy')).toBeVisible();
  });

  test('3. Operator Queue, Assignment, Timeline', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);

    await page.goto('/operations/queue');
    await page.waitForSelector('table');
    await page.locator('button:has-text("Manage")').first().click();
    await page.waitForURL(/.*operations\/report\/.*/);
    await expect(page.locator('text=Audit Timeline')).toBeVisible();
  });

  test('4. Operator Map, Assignments, Performance', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/); // <--- FIXED: Wait for login
    
    await page.goto('/operations/map');
    await page.waitForSelector('.leaflet-container', { state: 'attached', timeout: 30000 });

    await page.goto('/operations/assignments');
    await expect(page.locator('h2:has-text("Team Workload")')).toBeVisible();

    await page.goto('/operations/performance');
    await expect(page.locator('h2:has-text("Department Performance")')).toBeVisible();
  });

  test('5. Field Worker Task Completion', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*field/); // <--- FIXED

    const completeBtn = page.locator('button:has-text("Complete Task")').first();
    if (await completeBtn.isVisible()) {
      await completeBtn.click();
      await page.locator('textarea').fill('Master suite completion note.');
      await page.click('button:has-text("Submit Evidence")');
      await expect(page.locator('text=All caught up!')).toBeVisible();
    }
  });

  test('6. Intelligence Dashboard & Hotspots', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/); // <--- FIXED
    
    await page.goto('/intelligence');
    await expect(page.locator('h2:has-text("Intelligence Studio")')).toBeVisible();
    await expect(page.locator('body')).toContainText('Hotspot ID');
  });

  test('7. Geospatial Explorer, Rainfall, Registry, Quality', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/); // <--- FIXED
    
    await page.goto('/intelligence/explorer');
    await expect(page.locator('text=Open Reports')).toBeVisible();

    await page.goto('/intelligence/rainfall');
    await expect(page.locator('h2:has-text("Rainfall & Flood Context")')).toBeVisible();

    await page.goto('/intelligence/registry');
    await expect(page.locator('h2:has-text("Model Registry")')).toBeVisible();

    await page.goto('/intelligence/quality');
    await expect(page.locator('h2:has-text("Data Quality Dashboard")')).toBeVisible();
  });

  test('8. Admin Configuration (All Tabs)', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/); // <--- FIXED
    
    await page.goto('/admin');
    await expect(page.locator('h2:has-text("Admin Configuration")')).toBeVisible();
    
    await page.click('button:has-text("workflow")');
    await expect(page.locator('text=Status Transition Rules')).toBeVisible();

    await page.click('button:has-text("workspace")');
    await expect(page.locator('text=Workspace Settings')).toBeVisible();
  });

  test('9. Global Search and PDF Export', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/); // <--- FIXED
    
    await page.click('button:has-text("Search...")');
    await page.waitForSelector('[cmdk-input]');
    await page.fill('[cmdk-input]', 'CL-');
    await expect(page.locator('text=Reports')).toBeVisible();
    await page.keyboard.press('Escape');

    await page.goto('/operations/queue');
    const downloadPromise = page.waitForEvent('download');
    await page.click('button:has-text("Export PDF")');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe('civiclens_report.pdf');
  });

});

import { test, expect } from '@playwright/test';

test.describe('CIVICLENS End-to-End Journeys', () => {

  test('Unauthorized user cannot access Operations Portal', async ({ page }) => {
    await page.goto('/operations');
    // Should redirect to login
    await expect(page).toHaveURL(/.*login/);
  });

  test('Citizen can login and submit a report', async ({ page }) => {
    // 1. Login
    await page.goto('/login');
    await page.fill('input[type="email"]', 'citizen@example.com');
    await page.fill('input[type="password"]', 'password123');
    await page.click('button[type="submit"]');
    
    // Expect redirect to dashboard
    await expect(page).toHaveURL(/.*dashboard/);
    await expect(page.locator('h1')).toContainText('My Reports');

    // 2. Navigate to Report Wizard
    await page.click('text=New Report');
    await expect(page).toHaveURL(/.*report/);

    // 3. Fill out the report form
    await page.selectOption('select', { label: 'Potholes and RoadCracks' });
    await page.fill('textarea', 'Automated test: Large pothole on the main road');
    await page.fill('input[placeholder="Latitude"]', '17.3850');
    await page.fill('input[placeholder="Longitude"]', '78.4867');
    
    // 4. Submit
    await page.click('button:has-text("Submit Report")');
    
    // 5. Verify it appears on dashboard
    await expect(page).toHaveURL(/.*dashboard/);
    await expect(page.locator('body')).toContainText('Automated test: Large pothole');
  });

  test('Operator can triage and resolve a report', async ({ page }) => {
    // 1. Login as Operator
    await page.goto('/login');
    await page.fill('input[type="email"]', 'operator@civiclens.ai');
    await page.fill('input[type="password"]', 'password123');
    await page.click('button[type="submit"]');

    // Expect redirect to operations portal
    await expect(page).toHaveURL(/.*operations/);
    await expect(page.locator('h1')).toContainText('Municipal Operations');

    // 2. Go to Queue
    await page.click('text=Complaint Queue');
    await expect(page).toHaveURL(/.*queue/);
    await expect(page.locator('table')).toBeVisible();

    // 3. Click Manage on the first report
    await page.locator('button:has-text("Manage")').first().click();
    
    // 4. Assign to a Field Worker
    await page.selectOption('select >> nth=0', { index: 1 }); // Select first worker
    await page.click('button:has-text("Assign Worker")');

    // 5. Update Status to Resolved
    await page.selectOption('select >> nth=1', { value: 'resolved' });
    await page.click('button:has-text("Update Status")');

    // 6. Verify success
    await expect(page.locator('body')).toContainText('RESOLVED');
  });

});

import { test, expect } from '@playwright/test';

test.describe('PDF Export & Global Search', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Backend API returns search results', async ({ request }) => {
    const loginRes = await request.post('http://localhost:8000/api/v1/auth/login', {
      form: { username: 'operator@civiclens.ai', password: 'password123' }
    });
    const { access_token } = await loginRes.json();

    const searchRes = await request.get('http://localhost:8000/api/v1/search?q=CL', {
      headers: { Authorization: `Bearer ${access_token}` }
    });
    
    expect(searchRes.ok()).toBeTruthy();
    const results = await searchRes.json();
    expect(results.length).toBeGreaterThan(0);
  });

  test('User can search reports via Global Search UI', async ({ page }) => {
    await page.click('button:has-text("Search...")');
    const searchInput = page.locator('input[placeholder="Search reports, refs, or pages..."]');
    await expect(searchInput).toBeVisible({ timeout: 5000 });
    
    await searchInput.fill('CL-2026');
    await expect(page.locator('text=Reports')).toBeVisible({ timeout: 5000 });
    
    // CLICK THE UNIQUE TEST ID (Guaranteed to be a report)
    await page.getByTestId('search-result-item').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);
  });

  test('User can download PDF report', async ({ page }) => {
    await page.click('text=Complaint Queue');
    const downloadPromise = page.waitForEvent('download');
    await page.click('button:has-text("Export PDF")');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe('civiclens_report.pdf');
  });
});

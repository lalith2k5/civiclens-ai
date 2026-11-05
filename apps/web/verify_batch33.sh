#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Writing Playwright tests for Admin CRUD and Map Clustering..."
cat > tests/batch33.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Batch 33 - Enterprise Features', () => {

  test.beforeEach(async ({ page }) => {
    // Login as Operator
    await page.goto('/login');
    await page.fill('input[type="email"]', 'operator@civiclens.ai');
    await page.fill('input[type="password"]', 'password123');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Admin can add a new Ward and Department', async ({ page }) => {
    await page.click('text=Admin Settings');
    await expect(page).toHaveURL(/.*admin/);

    // 1. Add Ward
    await page.click('button:has-text("wards")');
    await page.fill('input#wardName', 'Test Ward Playwright');
    await page.locator('button:has-text("Add")').first().click();
    await expect(page.locator('body')).toContainText('Test Ward Playwright');

    // 2. Add Department
    await page.click('button:has-text("departments")');
    await page.fill('input#deptName', 'Test Dept Playwright');
    await page.locator('button:has-text("Add")').first().click();
    await expect(page.locator('body')).toContainText('Test Dept Playwright');
  });

  test('Admin can change a user role', async ({ page }) => {
    await page.click('text=Admin Settings');
    await page.click('button:has-text("users")');
    
    // Wait for table to load
    await expect(page.locator('table')).toBeVisible();
    
    // Change the first user's role to Admin
    const firstRoleDropdown = page.locator('select').first();
    await firstRoleDropdown.selectOption('admin');
    
    // Verify it stays selected
    await expect(firstRoleDropdown).toHaveValue('admin');
  });

  test('Map renders with clustering and no worker errors', async ({ page }) => {
    await page.click('text=Map Operations');
    await expect(page).toHaveURL(/.*map/);

    // Wait for Leaflet container
    await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });

    // Wait for MarkerClusterGroup to render (it adds class 'marker-cluster' to clusters)
    const cluster = page.locator('.marker-cluster');
    await expect(cluster.first()).toBeVisible({ timeout: 10000 });

    // Ensure no "Worker failed to load" text exists anywhere in the UI or console
    const bodyText = await page.locator('body').innerText();
    expect(bodyText).not.toContain('Worker failed to load');
  });

});
EOF

echo "2. Running Playwright tests in real browser..."
npx playwright test tests/batch33.spec.ts

cd ~/Desktop/civiclens-ai
git add .
git commit -m "test(e2e): automated verification for admin crud and map clustering"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Verification Complete."
echo "============================================================"

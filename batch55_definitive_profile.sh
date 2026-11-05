#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Fixing Playwright Test for Profile..."
cat > $WEB_DIR/tests/batch54.spec.ts << 'EOF'
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
EOF

echo "2. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch54.spec.ts || TEST_FAILED=true

echo "3. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Profile, Categories, and Bulk Actions work."
fi

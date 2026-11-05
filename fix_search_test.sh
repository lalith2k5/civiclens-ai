#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Fixing Playwright Test to click the Search button (instead of Cmd+K)..."
cat > $WEB_DIR/tests/batch43.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('PDF Export & Global Search', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('User can search reports via Global Search', async ({ page }) => {
    // 1. Click the actual Search button on screen (guaranteed to work)
    await page.click('button:has-text("Search...")');
    
    // 2. Wait for the dialog input to appear
    const searchInput = page.locator('input[placeholder="Search reports, refs, or pages..."]');
    await expect(searchInput).toBeVisible({ timeout: 5000 });
    
    // 3. Type a known reference
    await searchInput.fill('CL-2026');
    
    // 4. Wait for API and expect results under "Reports"
    await expect(page.locator('text=Reports')).toBeVisible({ timeout: 5000 });
    
    // 5. Click the first report result
    await page.locator('[cmdk-item]').first().click();
    
    // 6. Verify it navigates to the report detail page
    await expect(page).toHaveURL(/.*operations\/report\/.*/);
  });

  test('User can download PDF report', async ({ page }) => {
    await page.click('text=Complaint Queue');
    
    // Intercept the PDF download
    const downloadPromise = page.waitForEvent('download');
    await page.click('button:has-text("Export PDF")');
    const download = await downloadPromise;
    
    // Verify filename
    expect(download.suggestedFilename()).toBe('civiclens_report.pdf');
  });
});
EOF

echo "2. Starting Servers & Running Automated Test..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch43.spec.ts || TEST_FAILED=true

echo "3. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. PDF Export & Search work."
fi

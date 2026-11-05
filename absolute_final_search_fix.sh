#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Adding a unique test ID to the Search Result items..."
# Add data-testid to the Command.Item for reports
sed -i '' 's|<Command.Item key={r.id} onSelect=|<Command.Item data-testid="search-result-item" key={r.id} onSelect=|' $WEB_DIR/src/components/layout/app-shell.tsx

echo "2. Updating Playwright Test to click the exact test ID..."
cat > $WEB_DIR/tests/batch43.spec.ts << 'EOF'
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
EOF

echo "3. Starting Servers & Running Automated Tests..."
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

echo "4. Shutting down servers..."
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

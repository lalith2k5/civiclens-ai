#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Updating Playwright Test to wait for URL navigation..."
cat > $WEB_DIR/tests/batch36.spec.ts << 'EOF'
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
    
    // WAIT FOR THE REPORT URL TO LOAD
    await page.waitForURL(/.*operations\/report\/.*/);
    
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
npx playwright test tests/batch36.spec.ts || TEST_FAILED=true

echo "3. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Field Worker UI & Notifications work."
fi

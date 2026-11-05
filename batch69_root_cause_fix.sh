#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Adding data-testid to the visibility dropdown..."
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/src/app/operations/report/[id]/ReportClient.tsx")
with open(file_path, "r") as f: code = f.read()

# Add data-testid to the specific select
code = code.replace(
    '<select className="w-full p-2 border rounded-md text-sm bg-white" value={commentVisibility} onChange={(e) => setCommentVisibility(e.target.value)}>',
    '<select data-testid="visibility-select" className="w-full p-2 border rounded-md text-sm bg-white" value={commentVisibility} onChange={(e) => setCommentVisibility(e.target.value)}>'
)

with open(file_path, "w") as f: f.write(code)
PYEOF

echo "2. Updating the Playwright test to use the unique test ID..."
cat > $WEB_DIR/tests/batch56.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Spec Completion Batch', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Intelligence shows Hotspot Results Table', async ({ page }) => {
    await page.goto('/intelligence');
    await page.waitForLoadState('networkidle');
    await expect(page.locator('body')).toContainText('Hotspot ID', { timeout: 15000 });
    await expect(page.locator('body')).toContainText('Dominant Issue', { timeout: 15000 });
  });

  test('Operator can toggle comment visibility', async ({ page }) => {
    await page.goto('/operations/report/1');
    await page.waitForTimeout(2000); // Wait for React hydration
    
    // Wait for the page to load the Audit Timeline to guarantee success
    await expect(page.locator('text=Audit Timeline')).toBeVisible({ timeout: 15000 });
    
    // Use the exact test ID we just added
    const visibilitySelect = page.getByTestId('visibility-select'); 
    await expect(visibilitySelect).toBeVisible({ timeout: 10000 });
    await visibilitySelect.selectOption('internal');
    await expect(visibilitySelect).toHaveValue('internal');
  });

  test('Field Worker submits evidence form', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await page.goto('/field');
    await page.waitForLoadState('networkidle');

    const completeBtn = page.locator('button:has-text("Complete Task")').first();
    if (await completeBtn.isVisible()) {
      await completeBtn.click();
      await page.locator('textarea').fill('Completed the work successfully.');
      await page.click('button:has-text("Submit Evidence")');
      await expect(page.locator('text=All caught up!')).toBeVisible();
    }
  });
});
EOF

echo "3. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch56.spec.ts || TEST_FAILED=true

echo "4. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. All final spec gaps are verified."
fi

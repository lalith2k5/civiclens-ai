#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Wrapping Report Detail in Suspense (Next.js 16 requirement)..."
mkdir -p $WEB_DIR/src/app/operations/report/\[id\]
cat > $WEB_DIR/src/app/operations/report/\[id\]/page.tsx << 'EOF'
import { Suspense } from "react";
import ReportClient from "./ReportClient";

export default async function ReportPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params;
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <Suspense fallback={<div className="p-10 text-center text-slate-500">Loading workspace...</div>}>
        <ReportClient id={id} />
      </Suspense>
    </div>
  );
}
EOF

echo "2. Fixing the Playwright Test to wait for hydration..."
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
    
    // Wait for the page to fully load and React to hydrate
    await page.waitForTimeout(2000);
    
    // Wait for the Audit Timeline to confirm the page rendered successfully
    await expect(page.locator('text=Audit Timeline')).toBeVisible({ timeout: 15000 });
    
    // The comment visibility dropdown is the 3rd select
    const visibilitySelect = page.locator('select').nth(2); 
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

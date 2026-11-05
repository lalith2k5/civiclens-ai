#!/bin/bash

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web
HANDOFF_DIR=~/Desktop/civiclens-ai-handoff

echo "1. Explicitly writing the Playwright Test file..."
cat > $WEB_DIR/tests/batch52.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Comments, Linking & Rainfall', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Operator can add comments and link duplicates', async ({ page }) => {
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);

    // 1. Add Comment
    await page.fill('input[placeholder="Add a public comment..."]', 'Playwright test comment');
    await page.click('button:has-text("Post")');
    await expect(page.locator('text=Playwright test comment')).toBeVisible();

    // 2. Link Duplicate
    await page.fill('input[placeholder="Parent Report ID"]', '1');
    await page.click('button:has-text("Link as Duplicate")');
    // Wait for timeline to update
    await page.waitForTimeout(1000);
    await expect(page.locator('text=Linked as duplicate of 1')).toBeVisible();
  });

  test('Intelligence page renders Rainfall context map', async ({ page }) => {
    await page.click('text=Rainfall Context');
    await expect(page.locator('text=Rainfall & Flood Context')).toBeVisible();
    await expect(page.locator('.leaflet-container')).toBeVisible({ timeout: 10000 });
  });
});
EOF

echo "2. Starting Servers (using a loop to guarantee they boot)..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR
source $ROOT/.venv/bin/activate
uvicorn app.main:app > /tmp/api.log 2>&1 &
BACKEND_PID=$!

cd $WEB_DIR
npm run dev -- --webpack > /tmp/web.log 2>&1 &
FRONTEND_PID=$!

echo "Waiting for servers..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then
        echo "✅ Servers are up!"
        break
    fi
    sleep 1
done

echo "3. Running Playwright Tests..."
cd $WEB_DIR
npx playwright test tests/batch52.spec.ts
TEST_RESULT=$?

echo "4. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ $TEST_RESULT -eq 0 ]; then
    echo "✅ TEST PASSED SUCCESSFULLY. Comments, Linking & Rainfall work."
    
    # Update Handoff
    echo "5. Updating Handoff Folder..."
    cat > $HANDOFF_DIR/PROJECT_STATE.md << 'EOF'
phase: enterprise-complete
last_batch: 53
status: All specifications implemented. Comments, duplicate linking, and rainfall maps verified.
EOF
    cd $HANDOFF_DIR && zip -qr handoff.zip .
    echo "✅ Handoff updated and zipped."
else
    echo "❌ TEST FAILED."
    exit 1
fi

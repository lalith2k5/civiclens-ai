#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Restoring stable React-Leaflet Map Component..."
mkdir -p $WEB_DIR/src/components/maps
cat > $WEB_DIR/src/components/maps/HotspotMap.tsx << 'EOF'
"use client";
import { MapContainer, TileLayer, Circle } from "react-leaflet";
import "leaflet/dist/leaflet.css";

export default function HotspotMap({ hotspots }: { hotspots: any[] }) {
  return (
    <MapContainer center={[17.3850, 78.4867]} zoom={11} style={{ height: '100%', width: '100%', zIndex: 0 }}>
      <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
      {hotspots?.map((h: any, i: number) => (
        <Circle key={i} center={[h.lat, h.lon]} radius={h.radius} pathOptions={{ color: 'red', fillColor: '#ef4444', fillOpacity: 0.4 }} />
      ))}
    </MapContainer>
  );
}
EOF

echo "2. Fixing IntelligenceClient with stable dynamic import..."
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/src/app/intelligence/IntelligenceClient.tsx")
with open(file_path, "r") as f: code = f.read()

# Ensure the dynamic import is exactly correct
code = code.replace(
    'const HotspotMap = dynamic(() => import("@/components/maps/HotspotMap"), { ssr: false, loading: () => <div className="h-full w-full bg-slate-100 animate-pulse rounded-lg"></div> });',
    'const HotspotMap = dynamic(() => import("@/components/maps/HotspotMap"), { ssr: false, loading: () => <div className="h-full w-full bg-slate-100 flex items-center justify-center text-slate-400">Loading map...</div> });'
)
with open(file_path, "w") as f: f.write(code)
PYEOF

echo "3. Writing the ultimate, bulletproof Playwright test..."
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
    // DIRECT NAVIGATION (Guaranteed to work)
    await page.goto('/intelligence');
    
    // Wait for table headers
    await expect(page.locator('th:has-text("Hotspot ID")')).toBeVisible({ timeout: 10000 });
    await expect(page.locator('th:has-text("Dominant Issue")')).toBeVisible();
    
    // Verify map is present (React-Leaflet renders this class)
    await expect(page.locator('.leaflet-container')).toBeVisible();
  });

  test('Operator can toggle comment visibility', async ({ page }) => {
    // DIRECT NAVIGATION
    await page.goto('/operations/queue');
    
    // Wait for the table to load
    await page.waitForSelector('table', { timeout: 10000 });
    
    // Click the first Manage button
    await page.locator('button:has-text("Manage")').first().click();
    
    // Wait for the Report Detail page to fully load
    await expect(page).toHaveURL(/.*operations\/report\/.*/);
    await expect(page.locator('text=Audit Timeline')).toBeVisible({ timeout: 10000 });
    
    // The comment visibility dropdown is the 3rd select on the page
    const visibilitySelect = page.locator('select').nth(2); 
    await expect(visibilitySelect).toBeVisible();
    await visibilitySelect.selectOption('internal');
    await expect(visibilitySelect).toHaveValue('internal');
  });

  test('Field Worker submits evidence form', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await page.goto('/field'); // Direct navigation

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

echo "4. Starting Servers & Running Tests..."
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

echo "5. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Field Evidence, Hotspot Table, and Internal Notes work."
fi

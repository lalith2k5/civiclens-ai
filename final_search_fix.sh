#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Rewriting main.py cleanly to guarantee search is mounted..."
cat > $API_DIR/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api import auth, citizen, ops, analytics, ml, admin, notifications, search

app = FastAPI(title="CIVICLENS API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(citizen.router, prefix="/api/v1", tags=["Citizen Portal"])
app.include_router(ops.router, prefix="/api/v1/ops", tags=["Operations Portal"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(ml.router, prefix="/api/v1/ml", tags=["Machine Learning"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin Config"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["Notifications"])
app.include_router(search.router, prefix="/api/v1/search", tags=["Search"])

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok"}
EOF

echo "2. Rewriting search.py cleanly..."
cat > $API_DIR/app/api/search.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Complaint, User
from ..core.security import get_current_user

router = APIRouter()

@router.get("")
def global_search(q: str = Query(..., min_length=2), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    results = db.query(Complaint).filter(
        (Complaint.public_ref.ilike(f"%{q}%")) | 
        (Complaint.description.ilike(f"%{q}%"))
    ).limit(10).all()
    
    return [{"id": c.id, "public_ref": c.public_ref, "description": c.description, "category": c.category} for c in results]
EOF

echo "3. Fixing Frontend Search URL and cmdk filtering..."
sed -i '' 's|fetch(`${API_URL}/search/?q=${searchQuery}`|fetch(`${API_URL}/search?q=${searchQuery}`|' $WEB_DIR/src/components/layout/app-shell.tsx
# Add shouldFilter={false} to disable cmdk's internal fuzzy search so our API results always show
sed -i '' 's|<Command.Dialog open={open} onOpenChange={setOpen}|<Command.Dialog open={open} onOpenChange={setOpen} shouldFilter={false}|' $WEB_DIR/src/components/layout/app-shell.tsx

echo "4. Updating Playwright Test to verify API directly and wait for UI..."
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
    // Login to get token
    const loginRes = await request.post('http://localhost:8000/api/v1/auth/login', {
      form: { username: 'operator@civiclens.ai', password: 'password123' }
    });
    const { access_token } = await loginRes.json();

    // Call search API
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
    
    // Wait for the Reports heading to appear
    await expect(page.locator('text=Reports')).toBeVisible({ timeout: 5000 });
    
    // Click the first report
    await page.locator('[cmdk-item]').first().click();
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

echo "5. Starting Servers & Running Automated Tests..."
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

echo "6. Shutting down servers..."
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

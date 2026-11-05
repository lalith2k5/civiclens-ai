#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web
HANDOFF_DIR=~/Desktop/civiclens-ai-handoff

echo "1. Fixing Backend SLA Sorting..."
cat > $API_DIR/app/api/admin.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.models import User, Ward, Department, City, UserRole, SLAConfig
from ..core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class WardCreate(BaseModel):
    name: str
    code: str

class DeptCreate(BaseModel):
    name: str

class UserRoleUpdate(BaseModel):
    role: UserRole

class SLACreate(BaseModel):
    priority: str
    hours: int

@router.get("/users")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]

@router.put("/users/{user_id}/role")
def update_user_role(user_id: int, payload: UserRoleUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.role = payload.role
    db.commit()
    return {"message": "Role updated"}

@router.get("/wards")
def get_wards(db: Session = Depends(get_db)):
    return db.query(Ward).all()

@router.post("/wards")
def create_ward(ward: WardCreate, db: Session = Depends(get_db)):
    new_ward = Ward(city_id=1, name=ward.name, code=ward.code)
    db.add(new_ward); db.commit(); db.refresh(new_ward)
    return new_ward

@router.delete("/wards/{ward_id}")
def delete_ward(ward_id: int, db: Session = Depends(get_db)):
    ward = db.query(Ward).filter(Ward.id == ward_id).first()
    if not ward: raise HTTPException(status_code=404, detail="Ward not found")
    db.delete(ward); db.commit()
    return {"message": "Ward deleted"}

@router.get("/departments")
def get_depts(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.post("/departments")
def create_dept(dept: DeptCreate, db: Session = Depends(get_db)):
    new_dept = Department(city_id=1, name=dept.name)
    db.add(new_dept); db.commit(); db.refresh(new_dept)
    return new_dept

@router.get("/sla")
def get_sla(db: Session = Depends(get_db)):
    configs = db.query(SLAConfig).all()
    if not configs:
        defaults = [SLAConfig(priority="Critical", hours=24), SLAConfig(priority="High", hours=72), SLAConfig(priority="Medium", hours=168)]
        db.add_all(defaults); db.commit()
        configs = defaults
    
    # FORCE ORDERING: Critical -> High -> Medium
    order_map = {"Critical": 1, "High": 2, "Medium": 3}
    sorted_configs = sorted(configs, key=lambda x: order_map.get(x.priority, 4))
    
    return [{"id": c.id, "priority": c.priority, "hours": c.hours} for c in sorted_configs]

@router.post("/sla")
def update_sla(payload: SLACreate, db: Session = Depends(get_db)):
    config = db.query(SLAConfig).filter(SLAConfig.priority == payload.priority).first()
    if config:
        config.hours = payload.hours
    else:
        db.add(SLAConfig(priority=payload.priority, hours=payload.hours))
    db.commit()
    return {"status": "ok"}
EOF

echo "2. Updating Test with Wait Time..."
cat > $WEB_DIR/tests/batch50.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Hotspots & SLA', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('Intelligence page renders Hotspot map with circles', async ({ page }) => {
    await page.goto('/intelligence');
    await expect(page.locator('text=Hotspot Clustering (DBSCAN)')).toBeVisible();
    await expect(page.locator('.leaflet-container')).toBeVisible();
  });

  test('Admin can configure SLA rules', async ({ page }) => {
    await page.click('text=Admin Settings');
    await page.click('button:has-text("sla")');
    await expect(page.locator('text=SLA Configuration')).toBeVisible();
    
    const criticalInput = page.locator('input[type="number"]').first();
    await criticalInput.fill('12');
    await criticalInput.blur();
    
    // Wait for API to finish
    await page.waitForTimeout(1500); 
    
    await page.reload();
    await page.click('button:has-text("sla")');
    await expect(page.locator('input[type="number"]').first()).toHaveValue('12');
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
npx playwright test tests/batch50.spec.ts || TEST_FAILED=true

echo "4. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Hotspots and SLA work."
fi

echo "5. Updating Handoff Folder..."
cat > $HANDOFF_DIR/PROJECT_STATE.md << 'EOF'
phase: enterprise-complete
last_batch: 51
status: All specifications implemented. Docker deployment validated.
features: 
- Auth/JWT
- Citizen Reporting & ML Image Classification
- Ops Queue & Assignment
- Field Worker Mobile UI & Notifications
- Map Operations & DBSCAN Hotspots
- Intelligence (Forecasting, ECharts, Model Registry, Data Quality)
- Admin (Wards, Depts, Users, SLA Config)
- Audit Timelines
- Multilingual (English, Telugu, Hindi)
- PDF & CSV Exports
EOF

cat > $HANDOFF_DIR/HANDOFF.md << 'EOF'
# CIVICLENS AI — Handoff

## Status
The entire CIVICLENS AI platform is fully built, tested, and deployment-ready.
All features from the SRS and UI/UX specification have been implemented.

## How to Run
Use the `ds-start` shortcut, or run:
Backend: `cd apps/api && source .venv/bin/activate && uvicorn app.main:app --reload`
Frontend: `cd apps/web && npm run dev`

## Deployment
Run `docker-compose up --build -d` to deploy the entire stack (Postgres, FastAPI, Next.js).
EOF

cd $HANDOFF_DIR
zip -qr handoff.zip .
echo "✅ Handoff updated and zipped."

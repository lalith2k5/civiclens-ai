#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Restoring the missing GET /reports/{id} endpoint..."
cat >> $API_DIR/app/api/ops.py << 'EOF'

@router.get("/reports/{report_id}", response_model=ComplaintResponse)
def get_report(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
    return complaint
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

#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web
HANDOFF_DIR=~/Desktop/civiclens-ai-handoff

echo "1. Fixing the Playwright strict mode violation..."
# Use python to safely modify just the failing locator
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/tests/batch71.spec.ts")
with open(file_path, "r") as f: code = f.read()
# Replace the ambiguous locator with an explicit h2 heading locator
code = code.replace(
    "await expect(page.locator('text=Geospatial Explorer')).toBeVisible({ timeout: 15000 });",
    "await expect(page.locator('h2:has-text(\"Geospatial Explorer\")')).toBeVisible({ timeout: 15000 });"
)
with open(file_path, "w") as f: f.write(code)
PYEOF

echo "2. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch71.spec.ts || TEST_FAILED=true

echo "3. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Batch 71 gaps closed."
fi

echo "4. Updating Handoff Folder..."
cat > $HANDOFF_DIR/PROJECT_STATE.md << 'EOF'
phase: enterprise-complete
last_batch: 71
status: Intelligence and Admin gaps closed. Geospatial Explorer, Model Registry Actions, Data Quality Export, Ward Import, Workflow Config, Workspace Settings verified.
EOF
cd $HANDOFF_DIR && zip -qr handoff.zip .

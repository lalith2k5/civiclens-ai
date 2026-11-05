#!/bin/bash
set -e

# Use absolute paths to guarantee no "No such file or directory" errors
ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Cleaning up old servers..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

echo "2. Starting Backend API..."
cd $API_DIR
source $ROOT/.venv/bin/activate
uvicorn app.main:app > /tmp/api.log 2>&1 &
BACKEND_PID=$!

echo "3. Starting Frontend UI..."
cd $WEB_DIR
npm run dev -- --webpack > /tmp/web.log 2>&1 &
FRONTEND_PID=$!

echo "4. Waiting for servers to boot (max 30s)..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then
        echo "✅ Servers are up!"
        break
    fi
    sleep 1
done

echo "5. Running Playwright Browser Test for Field Worker..."
cd $WEB_DIR
# Force it to use the locally installed playwright
npx playwright test tests/batch36.spec.ts || TEST_FAILED=true

echo "6. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "============================================================"
    echo "❌ TEST FAILED. Please review the output above."
    echo "============================================================"
    exit 1
else
    echo "============================================================"
    echo "✅ TEST PASSED SUCCESSFULLY. Field Worker UI & Notifications work."
    echo "============================================================"
fi

#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai

echo "1. Cleaning up old servers on ports 3000 and 8000..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

echo "2. Starting Backend API in background..."
cd apps/api
source ../../.venv/bin/activate
uvicorn app.main:app > /tmp/api.log 2>&1 &
BACKEND_PID=$!
cd ../..

echo "3. Starting Frontend UI in background..."
cd apps/web
npm run dev -- --webpack > /tmp/web.log 2>&1 &
FRONTEND_PID=$!
cd ../..

echo "4. Waiting for servers to be ready (max 30 seconds)..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then
        echo "✅ Servers are up!"
        break
    fi
    sleep 1
done

echo "5. Running Playwright Browser Tests (Admin CRUD & Map Clustering)..."
cd apps/web
npx playwright test tests/batch33.spec.ts || TEST_FAILED=true

echo "6. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
# Kill any orphaned next/uvicorn processes
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "============================================================"
    echo "❌ TESTS FAILED. Please review the output above."
    echo "============================================================"
    exit 1
else
    echo "============================================================"
    echo "✅ TESTS PASSED SUCCESSFULLY. The features are fully functional."
    echo "============================================================"
fi

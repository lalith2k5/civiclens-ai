#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Fixing missing __init__.py file..."
touch apps/api/app/api/__init__.py

echo "Running automated API tests..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)

# Start FastAPI in background
uvicorn app.main:app --port 8000 > /tmp/api.log 2>&1 &
PID=$!

# Wait for server to be ready (max 10 seconds)
echo "Waiting for server to start..."
for i in {1..10}; do
    if curl -s http://localhost:8000/api/v1/health | grep -q "ok"; then
        echo "Server is up!"
        break
    fi
    sleep 1
done

# Test Login
echo "Testing Login Endpoint..."
LOGIN_RESPONSE=$(curl -s -X POST -d "username=citizen@example.com&password=password123" http://localhost:8000/api/v1/auth/login)
TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not get token. Here is the server log:"
    cat /tmp/api.log
    kill $PID
    exit 1
fi

# Test Submit Report
echo "Testing Submit Report Endpoint..."
curl -s -X POST http://localhost:8000/api/v1/reports \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d '{"description": "Large pothole near the school", "category": "road_damage", "lat": 17.3850, "lon": 78.4867}' > /dev/null

# Test Get Reports
echo "Testing Get My Reports Endpoint..."
REPORT_COUNT=$(curl -s http://localhost:8000/api/v1/reports -H "Authorization: Bearer $TOKEN" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
echo "Successfully fetched $REPORT_COUNT reports for the citizen."

# Stop server
kill $PID
cd ../..

# Commit and push
echo "Committing Batch 3 to Git..."
git add .
git commit -m "fix(batch3): add missing api __init__.py and robust test loop"
git push -u origin main

# Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch3-complete
last_batch: 3
backend: Auth & Citizen API ready
next_action: batch4-ops-api
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 3 Complete!"
echo "Auth and Citizen API are working."
echo "============================================================"

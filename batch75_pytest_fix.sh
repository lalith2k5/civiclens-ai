#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web
HANDOFF_DIR=~/Desktop/civiclens-ai-handoff

echo "1. Adding conftest.py to fix the Python module path..."
cat > $API_DIR/tests/conftest.py << 'EOF'
import sys
import os

# Add the api directory to sys.path so 'app' can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
EOF

echo "2. Running pytest..."
cd $API_DIR
source $ROOT/.venv/bin/activate
pytest -q

echo "3. Running vitest..."
cd $WEB_DIR
npx vitest run

echo "4. Committing everything to Git..."
cd $ROOT
git add .
git commit -m "fix(tests): add conftest.py to fix pytest module path, verify all tests pass"
git push -u origin main

echo "5. Updating Handoff Folder..."
cat > $HANDOFF_DIR/PROJECT_STATE.md << 'EOF'
phase: project-complete
last_batch: 75
status: All tests passing. Pytest + Vitest verified locally. CI/CD pipeline ready.
EOF
cd $HANDOFF_DIR && zip -qr handoff.zip .

echo "============================================================"
echo "✅ Pytest and Vitest both pass. Handoff updated."
echo "============================================================"

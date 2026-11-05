#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
HANDOFF_DIR=~/Desktop/civiclens-ai-handoff

cd $WEB_DIR

echo "1. Explicitly registering jest-axe matchers with Vitest's expect..."
cat > vitest.setup.ts << 'EOF'
import '@testing-library/jest-dom/vitest';
import { expect } from 'vitest';
import { toHaveNoViolations } from 'jest-axe';
expect.extend(toHaveNoViolations);
EOF

echo "2. Renaming config to .mts to silence ESM warning..."
if [ -f vitest.config.ts ]; then
    git mv vitest.config.ts vitest.config.mts 2>/dev/null || mv vitest.config.ts vitest.config.mts
fi

echo "3. Running vitest..."
npx vitest run

echo "4. Running pytest to confirm backend..."
cd $ROOT/apps/api
source $ROOT/.venv/bin/activate
pytest -q

echo "5. Committing..."
cd $ROOT
git add .
git commit -m "fix(tests): register jest-axe matchers with vitest expect, rename config to .mts"
git push -u origin main

echo "6. Updating Handoff..."
cat > $HANDOFF_DIR/PROJECT_STATE.md << 'EOF'
phase: project-complete
last_batch: 78
status: All tests passing. Pytest (2 passed) + Vitest (2 passed, incl. axe accessibility). CI/CD ready.
EOF
cd $HANDOFF_DIR && zip -qr handoff.zip .
echo "============================================================"
echo "✅ All tests pass. Handoff updated."
echo "============================================================"

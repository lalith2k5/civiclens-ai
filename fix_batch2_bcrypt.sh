#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

# 1. Fix bcrypt version compatibility
echo "Installing compatible bcrypt version..."
pip install "bcrypt==4.0.1" --force-reinstall

# 2. Run the seed script again
echo "Seeding the database..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -m app.seed
cd ../..

# 3. Commit and push
echo "Committing Batch 2 fix to Git..."
git add .
git commit -m "fix(batch2): pin bcrypt to 4.0.1 for passlib compatibility and seed database"
git push -u origin main

# 4. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch2-complete
last_batch: 2
database: seeded
backend: FastAPI skeleton created
next_action: batch3-auth-and-citizen-api
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 2 Complete!"
echo "Database is seeded with 50 complaints."
echo "Backend is ready."
echo "============================================================"

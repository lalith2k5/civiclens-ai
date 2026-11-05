#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

# 1. Wipe the database clean to remove partial data
echo "Dropping and recreating database..."
dropdb --if-exists civiclens
createdb civiclens
psql -d civiclens -c "CREATE EXTENSION IF NOT EXISTS postgis;"

# 2. Run the seed script from a clean slate
echo "Seeding the database..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -m app.seed
cd ../..

# 3. Commit and push
echo "Committing Batch 2 to Git..."
git add .
git commit -m "chore(batch2): clean db reset and successful seed"
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

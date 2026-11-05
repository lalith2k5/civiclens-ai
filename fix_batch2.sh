#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

# 1. Fix the DB driver URL in config.py
echo "Fixing database driver URL..."
cat > apps/api/app/core/config.py << 'EOF'
from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    PROJECT_NAME: str = "CIVICLENS AI"
    DATABASE_URL: str = "postgresql+psycopg2://localhost:5432/civiclens"
    SECRET_KEY: str = "super-secret-dev-key-change-in-prod"
    class Config:
        env_file = ".env"
settings = Settings()
EOF

# 2. Run the seed script
echo "Seeding the database..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -m app.seed
cd ../..

# 3. Commit and push
echo "Committing Batch 2 fix to Git..."
git add .
git commit -m "fix(batch2): update sqlalchemy driver to psycopg2 and seed database"
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

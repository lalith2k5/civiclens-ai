#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

# 1. Fix Kaggle missing dependency
echo "Installing missing Kaggle dependency..."
pip install --quiet six

# 2. Retry Kaggle downloads
cd data/raw

echo "Downloading Urban Issues Dataset (Image Classifier)..."
kaggle datasets download -d akinduhiman/urban-issues-dataset -p images/complaints/urban_issues --unzip

echo "Downloading BMC Complaints Dataset (Resolution Time)..."
kaggle datasets download -d govindaramsriram/mumbai-nagar-seva-bmc-complaints -p complaints/bmc --unzip

# 3. Fix Git branch and push
cd ~/Desktop/civiclens-ai
echo "Fixing Git branch to 'main'..."
git branch -M main
git add .
git commit -m "chore(batch1): add kaggle datasets and fix branch name" || echo "Nothing new to commit"
git push -u origin main

# 4. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch1-complete
last_batch: 1
datasets_acquired:
  - BMC complaints (resolution_days)
  - Urban Issues (image classification)
  - India Flood Inventory
  - OSM Roads
next_action: batch2-database-schema-and-seed
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 1 fully complete and pushed to GitHub!"
echo "============================================================"

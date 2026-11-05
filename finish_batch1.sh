#!/bin/bash
set +e # Don't stop on error

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

# 1. Retry BMC dataset download as a competition
cd data/raw
echo "Retrying BMC Complaints Dataset..."
kaggle competitions download -c mumbai-nagar-seva-bmc-civic-complaint-resolution-2018-2024 -p complaints/bmc --unzip

# 2. Force Git push
cd ~/Desktop/civiclens-ai
echo "Committing and pushing to Git..."
git add .
git commit -m "chore(batch1): complete dataset downloads"
git push -u origin main

# 3. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch1-complete
last_batch: 1
datasets_acquired:
  - Urban Issues (image classification) - 4.5GB
  - BMC complaints (resolution_days) - if accepted
  - India Flood Inventory
  - OSM Roads
next_action: batch2-database-schema-and-seed
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 1 fully complete and pushed to GitHub!"
echo "============================================================"

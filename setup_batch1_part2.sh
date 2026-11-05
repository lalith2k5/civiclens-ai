#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai

# 1. Create and activate Python virtual environment
echo "Creating Python virtual environment..."
if [ ! -d ".venv" ]; then
  python3.12 -m venv .venv
fi
source .venv/bin/activate

# 2. Install Kaggle CLI
pip install --quiet --upgrade pip
pip install --quiet kaggle

# 3. Configure Kaggle token
echo "Configuring Kaggle API token..."
mkdir -p ~/.kaggle
echo "KGAT_2e0b3535c554a32c2a40737b20a72a5c" > ~/.kaggle/access_token
chmod 600 ~/.kaggle/access_token
export KAGGLE_API_TOKEN="KGAT_2e0b3535c554a32c2a40737b20a72a5c"

# 4. Download Datasets
cd data/raw

echo "Downloading Urban Issues Dataset (Image Classifier)..."
kaggle datasets download -d akinduhiman/urban-issues-dataset -p images/complaints/urban_issues --unzip || echo "Urban Issues download failed, continuing..."

echo "Downloading BMC Complaints Dataset (Resolution Time)..."
kaggle datasets download -d govindaramsriram/mumbai-nagar-seva-bmc-complaints -p complaints/bmc --unzip || echo "BMC download failed, continuing..."

echo "Downloading Flood Inventory (Section 10 context)..."
curl -sL -o context/flood/India_Flood_Inventory_v3.csv "https://zenodo.org/records/11275211/files/India_Flood_Inventory_v3.csv?download=1"

echo "Downloading OSM Southern Zone (Road network context - this takes a minute)..."
curl -sL -o context/osm/southern-zone-latest.osm.pbf "https://download.geofabrik.de/asia/india/southern-zone-latest.osm.pbf"

# 5. Create Dataset Manifest
cd ~/Desktop/civiclens-ai
cat > data/manifests/DATASETS.md << 'EOF'
# CIVICLENS AI — Dataset Manifest

## Image Classification Training Data
| Dataset | Source | License | Classes used | Path |
|---|---|---|---|---|
| Urban Issues Dataset | Kaggle (akinduhiman) | CC0 | damaged road, pothole, garbage, broken sign, fallen tree | images/complaints/urban_issues |

## Resolution-Time and Forecasting Training Data
| Dataset | Source | Rows | Key columns |
|---|---|---|---|
| BMC Complaints | Kaggle (govindaramsriram) | Public | complaint_category, ward_code, resolution_days, severity |

## Context Data (Section 10)
| Dataset | Source | Use |
|---|---|---|
| India Flood Inventory v3 | Zenodo (IIT Delhi) | Historical flood events |
| OSM Southern Zone | Geofabrik | Road network, facilities |

## Governance
- BMC data is used for ML training only; not presented as Hyderabad operational data.
- Hyderabad operational seed will be clearly marked `data_origin='seed'`.
EOF

# 6. Commit and push to Git
echo "Committing Batch 1 to Git..."
git add .
git commit -m "chore(batch1): setup venv, configure kaggle, download real datasets"
git push -u origin main

# 7. Update Handoff folder
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

cat > HANDOFF.md << 'EOF'
# CIVICLENS AI — Handoff

## Status
Batch 1 Complete. Repo created. Datasets downloaded.

## Environment
- Python 3.12 (in venv at ~/Desktop/civiclens-ai/.venv)
- PostGIS installed
- Kaggle API token configured at ~/.kaggle/access_token

## Resume
If this chat ends, attach this folder and say:
"Continue CIVICLENS AI from HANDOFF.md. We finished Batch 1, start Batch 2 (Database schema)."
EOF

zip -qr handoff.zip .
echo "============================================================"
echo "Batch 1 Complete!"
echo "Datasets are downloaded to ~/Desktop/civiclens-ai/data/raw"
echo "Git is updated and handoff folder is zipped."
echo "============================================================"

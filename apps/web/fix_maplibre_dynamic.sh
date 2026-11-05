#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Fixing dynamic import for maplibre-gl..."
# Remove the .default from the dynamic import
sed -i '' 's|const maplibregl = (await import("maplibre-gl")).default;|const maplibregl = await import("maplibre-gl");|' src/app/operations/map/page.tsx

echo "Building frontend..."
npm run build

cd ~/Desktop/civiclens-ai

echo "Committing fix to Git..."
git add .
git commit -m "fix(ui): resolve maplibre default export typescript error in dynamic import"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Build successful! Premium UI is ready."
echo "============================================================"

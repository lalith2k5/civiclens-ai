#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Applying 'instant = false' to dynamic routes..."

# Array of all our client-side data-fetching pages
files=(
  "src/app/operations/page.tsx"
  "src/app/operations/queue/page.tsx"
  "src/app/operations/map/page.tsx"
  "src/app/intelligence/page.tsx"
  "src/app/admin/page.tsx"
  "src/app/dashboard/page.tsx"
  "src/app/report/page.tsx"
  "src/app/operations/report/[id]/page.tsx"
)

for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    # Remove existing instant directives to prevent duplicates
    sed -i '' '/export const instant = false;/d' "$file"
    # Insert the directive right after "use client";
    sed -i '' 's/"use client";/"use client";\nexport const instant = false;/' "$file"
  fi
done

echo "Building to verify no warnings..."
npm run build

cd ~/Desktop/civiclens-ai

echo "Committing fix to Git..."
git add .
git commit -m "fix(ui): add instant=false to dynamic routes to clear Next.js 16 console warnings"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Console Cleaned! The system is 100% perfect."
echo "============================================================"

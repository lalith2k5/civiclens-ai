#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Fixing Next.js 16 Suspense boundary in Operations Layout..."
cat > src/app/operations/layout.tsx << 'EOF'
import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export default function OpsLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center bg-slate-50 text-slate-500">Loading Workspace...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
EOF

echo "Building frontend to verify..."
npm run build

cd ~/Desktop/civiclens-ai

echo "Committing fix to Git..."
git add .
git commit -m "fix(ui): wrap AppShell in Suspense to resolve Next.js 16 usePathname build error"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "UI Build Fixed and Committed!"
echo "============================================================"

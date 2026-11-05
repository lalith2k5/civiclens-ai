#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Fixing TypeScript errors..."

# 1. Fix the missing import in page.tsx
cat > src/app/page.tsx << 'EOF'
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { ArrowRight, MapPin, ShieldCheck, Activity } from "lucide-react"
import Link from "next/link"

export default function Home() {
  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      {/* Header */}
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <div className="flex items-center gap-2">
          <div className="h-8 w-8 rounded bg-primary flex items-center justify-center text-white font-bold">
            C
          </div>
          <span className="font-bold text-xl tracking-tight text-slate-900">CIVICLENS AI</span>
        </div>
        <nav className="flex gap-4">
          <Link href="/login">
            <Button variant="ghost">Sign In</Button>
          </Link>
          <Link href="/register">
            <Button>Report an Issue</Button>
          </Link>
        </nav>
      </header>

      {/* Hero Section */}
      <main className="flex-1 flex flex-col items-center justify-center text-center px-4 py-20">
        <Badge className="mb-4" variant="secondary">Hyderabad Pilot Phase</Badge>
        <h1 className="text-5xl font-extrabold tracking-tight text-slate-900 max-w-3xl mb-6">
          Intelligent Urban Problem Detection & Resolution
        </h1>
        <p className="text-lg text-slate-600 max-w-2xl mb-10">
          Connecting citizens, municipal operations teams, and data intelligence through transparent reporting, geospatial workflows, and evidence-based prediction.
        </p>
        
        <div className="flex gap-4">
          <Link href="/report">
            <Button size="lg" className="gap-2">
              Report an Issue <ArrowRight className="h-4 w-4" />
            </Button>
          </Link>
          <Link href="/operations">
            <Button size="lg" variant="outline">Operations Login</Button>
          </Link>
        </div>

        {/* Feature Cards */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 max-w-5xl mt-24 text-left">
          <div className="p-6 bg-white rounded-xl border shadow-sm">
            <MapPin className="h-10 w-10 text-primary mb-4" />
            <h3 className="font-bold text-lg mb-2">Geospatial Tracking</h3>
            <p className="text-slate-500 text-sm">Pin exact locations, track clusters of issues, and visualize city-wide infrastructure health.</p>
          </div>
          <div className="p-6 bg-white rounded-xl border shadow-sm">
            <ShieldCheck className="h-10 w-10 text-primary mb-4" />
            <h3 className="font-bold text-lg mb-2">Transparent Resolution</h3>
            <p className="text-slate-500 text-sm">Every action is logged. Citizens receive reference codes and can track the exact status of their reports.</p>
          </div>
          <div className="p-6 bg-white rounded-xl border shadow-sm">
            <Activity className="h-10 w-10 text-primary mb-4" />
            <h3 className="font-bold text-lg mb-2">AI-Powered Insights</h3>
            <p className="text-slate-500 text-sm">Automated duplicate detection, priority recommendations, and hotspot analysis for city planners.</p>
          </div>
        </div>
      </main>
      
      <footer className="py-6 text-center text-sm text-slate-500 border-t bg-white">
        © 2026 CIVICLENS AI. Not an emergency service.
      </footer>
    </div>
  )
}
EOF

# 2. Fix Tailwind darkMode TypeScript error
sed -i '' 's/darkMode: \["class"\],/darkMode: "class",/' tailwind.config.ts

echo "Building frontend..."
npm run build

cd ~/Desktop/civiclens-ai

# 3. Commit and push
echo "Committing Batch 5 to Git..."
git add .
git commit -m "fix(batch5): resolve ts errors for Badge import and tailwind darkMode"
git push -u origin main

# 4. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch5-complete
last_batch: 5
frontend: Next.js setup with premium design system and manual UI components
next_action: batch6-citizen-ui
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 5 Complete!"
echo "Frontend setup and design system are ready."
echo "============================================================"

#!/bin/bash
set -e

echo "Fixing broken Node.js symlink..."
brew reinstall node

echo "Verifying Node.js works..."
node --version
npm --version

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Setting up Next.js frontend..."

# Clean up any partial directory from the failed attempt
rm -rf apps/web
mkdir -p apps/web
cd apps/web

# 1. Create Next.js app non-interactively
npx -y create-next-app@latest ./ --typescript --eslint --tailwind --app --src-dir --import-alias "@/*" --use-npm

# 2. Install necessary frontend dependencies
echo "Installing frontend dependencies..."
npm install lucide-react framer-motion clsx tailwind-merge tailwindcss-animate

# 3. Setup shadcn/ui non-interactively
echo "Configuring shadcn/ui..."
mkdir -p src/components/ui
cat > components.json << 'EOF'
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "default",
  "rsc": true,
  "tsx": true,
  "tailwind": {
    "config": "tailwind.config.ts",
    "css": "src/app/globals.css",
    "baseColor": "slate",
    "cssVariables": true,
    "prefix": ""
  },
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  }
}
EOF

# Create utils file required by shadcn
mkdir -p src/lib
cat > src/lib/utils.ts << 'EOF'
import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
EOF

# Add base shadcn components
npx -y shadcn-ui@latest add button card badge table input label

# 4. Apply Premium Design System (Deep Forest/Teal palette)
echo "Applying premium design system..."
cat > src/app/globals.css << 'EOF'
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 210 20% 98%;
    --foreground: 222 47% 11%;
    --card: 0 0% 100%;
    --card-foreground: 222 47% 11%;
    --popover: 0 0% 100%;
    --popover-foreground: 222 47% 11%;
    --primary: 173 65% 26%;
    --primary-foreground: 210 40% 98%;
    --secondary: 173 30% 90%;
    --secondary-foreground: 173 65% 26%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 173 30% 90%;
    --accent-foreground: 173 65% 26%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 173 65% 26%;
    --radius: 0.5rem;
  }
  .dark {
    --background: 222 47% 11%;
    --foreground: 210 40% 98%;
    --card: 222 47% 11%;
    --card-foreground: 210 40% 98%;
    --popover: 222 47% 11%;
    --popover-foreground: 210 40% 98%;
    --primary: 173 65% 40%;
    --primary-foreground: 222 47% 11%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 173 65% 40%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
EOF

# 5. Update Tailwind config
cat > tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss"

const config = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
} satisfies Config

export default config
EOF

# 6. Create Premium Landing Page
cat > src/app/page.tsx << 'EOF'
import { Button } from "@/components/ui/button"
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
          <div className="p-6 bg-white rounded-xl shadow-sm border">
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

npx -y shadcn-ui@latest add badge

# 7. Create .env.local for API connection
cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:8000/api/v1
EOF

# 8. Build to verify no errors
echo "Building frontend..."
npm run build

cd ../..

# 9. Commit and push
echo "Committing Batch 5 to Git..."
git add .
git commit -m "feat(batch5): Next.js frontend, Tailwind, shadcn/ui, and premium landing page"
git push -u origin main

# 10. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch5-complete
last_batch: 5
frontend: Next.js setup with design system
next_action: batch6-citizen-ui
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 5 Complete!"
echo "Frontend setup and design system are ready."
echo "============================================================"

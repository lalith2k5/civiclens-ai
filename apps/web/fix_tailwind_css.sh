#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Ensuring PostCSS and Tailwind dependencies are installed..."
npm install -D tailwindcss @tailwindcss/postcss postcss autoprefixer

echo "2. Creating PostCSS configuration for Webpack..."
cat > postcss.config.mjs << 'EOF'
const config = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
export default config;
EOF

echo "3. Restoring Global CSS with your Premium Design System..."
cat > src/app/globals.css << 'EOF'
@import "tailwindcss";

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
  * {
    border-color: hsl(var(--border));
  }
  body {
    background-color: hsl(var(--background));
    color: hsl(var(--foreground));
    font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
  }
}
EOF

echo "4. Updating layout.tsx to import global CSS..."
cat > src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";
import QueryProvider from "@/components/providers/query-provider";

export const metadata: Metadata = {
  title: "CIVICLENS AI",
  description: "Intelligent Urban Problem Detection",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  );
}
EOF

echo "5. Checking Tailwind Config..."
cat > tailwind.config.ts << 'EOF'
import type { Config } from "tailwindcss"

const config = {
  darkMode: "class",
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
        primary: { DEFAULT: "hsl(var(--primary))", foreground: "hsl(var(--primary-foreground))" },
        secondary: { DEFAULT: "hsl(var(--secondary))", foreground: "hsl(var(--secondary-foreground))" },
        destructive: { DEFAULT: "hsl(var(--destructive))", foreground: "hsl(var(--destructive-foreground))" },
        muted: { DEFAULT: "hsl(var(--muted))", foreground: "hsl(var(--muted-foreground))" },
        accent: { DEFAULT: "hsl(var(--accent))", foreground: "hsl(var(--accent-foreground))" },
        card: { DEFAULT: "hsl(var(--card))", foreground: "hsl(var(--card-foreground))" },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
    },
  },
  plugins: [],
} satisfies Config

export default config
EOF

echo "6. Committing fix..."
git add .
git commit -m "fix(css): restore tailwind v4 postcss config and premium design tokens"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "CSS Restored! Please restart your frontend server."
echo "============================================================"

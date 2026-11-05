#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Adding Forecasting Endpoint (Moving Average)..."
cat >> $API_DIR/app/api/analytics.py << 'EOF'

import pandas as pd
from datetime import timedelta

@router.get("/forecast")
def get_forecast(db: Session = Depends(get_db)):
    # Get last 60 days of complaints
    sixty_days_ago = datetime.now() - timedelta(days=60)
    results = db.query(
        func.date(Complaint.created_at).label('date'),
        func.count(Complaint.id).label('count')
    ).filter(Complaint.created_at >= sixty_days_ago).group_by('date').all()
    
    if not results:
        return {"historical": [], "forecast": []}
        
    df = pd.DataFrame([{"date": str(r.date), "count": r.count} for r in results])
    df['date'] = pd.to_datetime(df['date'])
    df = df.set_index('date').resample('D').sum().fillna(0)
    
    # Simple 7-day moving average forecast
    df['MA7'] = df['count'].rolling(window=7, min_periods=1).mean()
    last_ma = df['MA7'].iloc[-1]
    
    historical = [{"date": d.strftime('%Y-%m-%d'), "count": int(row['count'])} for d, row in df.iterrows()]
    
    forecast = []
    last_date = df.index[-1]
    for i in range(1, 8): # Predict next 7 days
        next_date = last_date + timedelta(days=i)
        forecast.append({"date": next_date.strftime('%Y-%m-%d'), "predicted": round(float(last_ma), 1)})
        
    return {"historical": historical, "forecast": forecast}
EOF

echo "2. Creating i18n Dictionary for English, Telugu, and Hindi..."
mkdir -p $WEB_DIR/src/lib
cat > $WEB_DIR/src/lib/i18n.ts << 'EOF'
export const translations = {
  en: {
    overview: "Overview",
    queue: "Complaint Queue",
    map: "Map Operations",
    intelligence: "Intelligence",
    admin: "Admin Settings",
    municipal_ops: "Municipal Operations",
    search: "Search...",
    report_issue: "Report an Issue",
    dashboard: "My Reports",
    sign_in: "Sign In to CIVICLENS",
    lang: "English"
  },
  te: {
    overview: "అవలోకనం",
    queue: "ఫిర్యాదుల క్యూ",
    map: "మ్యాప్ కార్యకలాపాలు",
    intelligence: "ఇంటెలిజెన్స్",
    admin: "అడ్మిన్ సెట్టింగ్‌లు",
    municipal_ops: "మున్సిపల్ కార్యకలాపాలు",
    search: "వెతకండి...",
    report_issue: "సమస్యను నివేదించండి",
    dashboard: "నా నివేదికలు",
    sign_in: "CIVICLENS లో సైన్ ఇన్ చేయండి",
    lang: "తెలుగు"
  },
  hi: {
    overview: "अवलोकन",
    queue: "शिकायत कतार",
    map: "मानचित्र संचालन",
    intelligence: "इंटेलिजेंस",
    admin: "व्यवस्थापक सेटिंग्स",
    municipal_ops: "नगरपालिका संचालन",
    search: "खोजें...",
    report_issue: "समस्या की रिपोर्ट करें",
    dashboard: "मेरी रिपोर्ट",
    sign_in: "CIVICLENS में साइन इन करें",
    lang: "हिन्दी"
  }
};
export type Language = 'en' | 'te' | 'hi';
EOF

echo "3. Creating Language Context Provider..."
cat > $WEB_DIR/src/components/providers/language-provider.tsx << 'EOF'
"use client";
import { createContext, useContext, useState, useEffect } from "react";
import { translations, Language } from "@/lib/i18n";

const LanguageContext = createContext<any>(null);

export default function LanguageProvider({ children }: { children: React.ReactNode }) {
  const [lang, setLang] = useState<Language>('en');

  useEffect(() => {
    const saved = localStorage.getItem('civiclens_lang') as Language;
    if (saved) setLang(saved);
  }, []);

  const changeLang = (newLang: Language) => {
    setLang(newLang);
    localStorage.setItem('civiclens_lang', newLang);
  };

  const t = (key: keyof typeof translations['en']) => translations[lang][key] || translations['en'][key];

  return <LanguageContext.Provider value={{ lang, changeLang, t }}>{children}</LanguageContext.Provider>;
}

export const useLanguage = () => useContext(LanguageContext);
EOF

echo "4. Wrapping Layout with Language Provider..."
cat > $WEB_DIR/src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import "./globals.css";
import QueryProvider from "@/components/providers/query-provider";
import LanguageProvider from "@/components/providers/language-provider";

export const metadata: Metadata = { title: "CIVICLENS AI", description: "Intelligent Urban Problem Detection" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <QueryProvider>
          <LanguageProvider>{children}</LanguageProvider>
        </QueryProvider>
      </body>
    </html>
  );
}
EOF

echo "5. Updating App Shell with Language Switcher and Translations..."
# Since the App Shell is large, we use a targeted python script to patch it safely
python3 - << 'PYEOF'
import re
file_path = "~/Desktop/civiclens-ai/apps/web/src/components/layout/app-shell.tsx"
file_path = file_path.replace("~", "/Users/" + __import__('os').getlogin())
with open(file_path, "r") as f: code = f.read()

# Add import
code = code.replace('import { getToken, logout, API_URL } from "@/lib/api";', 'import { getToken, logout, API_URL } from "@/lib/api";\nimport { useLanguage } from "@/components/providers/language-provider";')

# Add hook
code = code.replace('const queryClient = useQueryClient();', 'const queryClient = useQueryClient();\n  const { lang, changeLang, t } = useLanguage();')

# Add Language Switcher to Header (next to Bell icon)
lang_switcher = '''
            <select 
              className="text-sm bg-slate-100 border-none rounded-md px-2 py-1.5 focus:ring-0 cursor-pointer font-medium"
              value={lang}
              onChange={(e) => changeLang(e.target.value as any)}
            >
              <option value="en">English</option>
              <option value="te">తెలుగు</option>
              <option value="hi">हिन्दी</option>
            </select>
'''
code = code.replace('<div className="relative">\n              <button onClick={() => setShowNotifs(!showNotifs)}', lang_switcher + '\n            <div className="relative">\n              <button onClick={() => setShowNotifs(!showNotifs)}')

# Translate Navigation & Headers
code = code.replace('{ name: "Overview", href: "/operations", icon: LayoutDashboard }', '{ name: t("overview"), href: "/operations", icon: LayoutDashboard }')
code = code.replace('{ name: "Complaint Queue", href: "/operations/queue", icon: ListTodo }', '{ name: t("queue"), href: "/operations/queue", icon: ListTodo }')
code = code.replace('{ name: "Map Operations", href: "/operations/map", icon: Map }', '{ name: t("map"), href: "/operations/map", icon: Map }')
code = code.replace('{ name: "Intelligence", href: "/intelligence", icon: Brain }', '{ name: t("intelligence"), href: "/intelligence", icon: Brain }')
code = code.replace('{ name: "Admin Settings", href: "/admin", icon: Settings }', '{ name: t("admin"), href: "/admin", icon: Settings }')
code = code.replace('Municipal Operations', '{t("municipal_ops")}')

with open(file_path, "w") as f: f.write(code)
print("Patched App Shell.")
PYEOF

echo "6. Updating Intelligence Dashboard with Forecast Chart..."
cat > $WEB_DIR/src/app/intelligence/IntelligenceClient.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import ReactECharts from 'echarts-for-react';
import { Brain, TrendingUp } from "lucide-react";

export default function Intelligence() {
  const { data: summary } = useQuery({ queryKey: ["summary"], queryFn: () => fetch(`${API_URL}/analytics/summary`).then(r => r.json()) });
  const { data: forecast } = useQuery({ queryKey: ["forecast"], queryFn: () => fetch(`${API_URL}/analytics/forecast`).then(r => r.json()) });

  const pieOptions = {
    tooltip: { trigger: 'item' },
    series: [{ type: 'pie', radius: ['40%', '70%'], data: summary?.categories?.map((c: any) => ({ value: c.count, name: c.category })) || [], itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 } }]
  };

  const historicalDates = forecast?.historical?.map((h: any) => h.date) || [];
  const forecastDates = forecast?.forecast?.map((f: any) => f.date) || [];
  const allDates = [...historicalDates, ...forecastDates];

  const histCounts = forecast?.historical?.map((h: any) => h.count) || [];
  const foreCounts = Array(histCounts.length).fill(null).concat(forecast?.forecast?.map((f: any) => f.predicted) || []);

  const lineOptions = {
    tooltip: { trigger: 'axis' },
    legend: { data: ['Actual Complaints', '7-Day Forecast'] },
    xAxis: { type: 'category', data: allDates },
    yAxis: { type: 'value' },
    series: [
      { name: 'Actual Complaints', data: histCounts, type: 'line', smooth: true, itemStyle: { color: '#176B61' } },
      { name: '7-Day Forecast', data: foreCounts, type: 'line', smooth: true, lineStyle: { type: 'dashed' }, itemStyle: { color: '#d97706' } }
    ]
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 mb-8">
        <div className="p-3 bg-[#176B61] text-white rounded-lg"><Brain className="h-6 w-6" /></div>
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Intelligence Studio</h2>
          <p className="text-slate-500">Advanced analytics and model-driven insights.</p>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4">Issue Distribution</h3>
          <ReactECharts option={pieOptions} style={{ height: 300 }} />
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4 flex items-center gap-2"><TrendingUp className="h-4 w-4 text-amber-600"/> Volume Forecast</h3>
          <ReactECharts option={lineOptions} style={{ height: 300 }} />
        </div>
      </div>
    </div>
  );
}
EOF

echo "7. Writing Playwright Test for Language & Forecast..."
cat > $WEB_DIR/tests/batch47.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Multilingual & Forecasting', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('User can change language to Telugu', async ({ page }) => {
    const langSelect = page.locator('select').first();
    await langSelect.selectOption('te');
    
    // Check if sidebar text updated to Telugu
    await expect(page.locator('text=అవలోకనం')).toBeVisible();
    await expect(page.locator('text=ఫిర్యాదుల క్యూ')).toBeVisible();
  });

  test('Forecast chart renders with actual and predicted data', async ({ page }) => {
    await page.goto('/intelligence');
    await expect(page.locator('.echarts-for-react')).toHaveCount(2);
    await expect(page.locator('text=7-Day Forecast')).toBeVisible();
  });
});
EOF

echo "8. Starting Servers & Running Automated Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch47.spec.ts || TEST_FAILED=true

echo "9. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Multilingual & Forecasting work."
fi

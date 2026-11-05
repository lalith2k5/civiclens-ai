#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Installing PDF Library in Backend..."
cd $API_DIR
source $ROOT/.venv/bin/activate
pip install --quiet fpdf2

echo "2. Creating PDF Export & Search Endpoints..."
cat >> $API_DIR/app/api/analytics.py << 'EOF'

from fpdf import FPDF
from fastapi.responses import FileResponse
import os

@router.get("/export-pdf")
def export_pdf(db: Session = Depends(get_db)):
    complaints = db.query(Complaint).limit(50).all() # Limit to 50 for PDF
    
    pdf = FPDF()
    pdf.add_page()
    pdf.set_font("Arial", 'B', 16)
    pdf.cell(200, 10, txt="CIVICLENS AI - City Operations Report", ln=True, align='C')
    pdf.set_font("Arial", size=10)
    pdf.cell(200, 10, txt="Hyderabad Pilot", ln=True, align='C')
    pdf.ln(10)
    
    # Table Header
    pdf.set_font("Arial", 'B', 10)
    pdf.cell(30, 10, "Ref ID", border=1)
    pdf.cell(40, 10, "Category", border=1)
    pdf.cell(30, 10, "Status", border=1)
    pdf.cell(30, 10, "Priority", border=1)
    pdf.cell(60, 10, "Location", border=1)
    pdf.ln()
    
    # Table Body
    pdf.set_font("Arial", size=9)
    for c in complaints:
        pdf.cell(30, 10, str(c.public_ref), border=1)
        pdf.cell(40, 10, str(c.category).replace('_', ' ')[:20], border=1)
        pdf.cell(30, 10, str(c.status), border=1)
        pdf.cell(30, 10, str(c.priority), border=1)
        pdf.cell(60, 10, f"{c.lat:.4f}, {c.lon:.4f}", border=1)
        pdf.ln()
        
    file_path = "/tmp/civiclens_report.pdf"
    pdf.output(file_path)
    return FileResponse(file_path, media_type="application/pdf", filename="civiclens_report.pdf")
EOF

cat > $API_DIR/app/api/search.py << 'EOF'
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Complaint
from ..core.security import get_current_user
from ..models.models import User

router = APIRouter()

@router.get("/")
def global_search(q: str = Query(..., min_length=2), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Search by public_ref or description
    results = db.query(Complaint).filter(
        (Complaint.public_ref.ilike(f"%{q}%")) | 
        (Complaint.description.ilike(f"%{q}%"))
    ).limit(10).all()
    
    return [{"id": c.id, "public_ref": c.public_ref, "description": c.description, "category": c.category} for c in results]
EOF

# Register search router in main.py
python -c "
import re
with open('app/main.py', 'r') as f: content = f.read()
if 'search' not in content:
    content = content.replace('from .api import auth, citizen, ops, analytics, ml, admin, notifications', 'from .api import auth, citizen, ops, analytics, ml, admin, notifications, search')
    content = content.replace('app.include_router(notifications.router', 'app.include_router(search.router, prefix=\"/api/v1/search\", tags=[\"Search\"])\napp.include_router(notifications.router')
    with open('app/main.py', 'w') as f: f.write(content)
"

echo "3. Updating Frontend: Adding PDF Button to Queue..."
cd $WEB_DIR
sed -i '' 's|<a href={`${API_URL}/analytics/export`} target="_blank"><Button variant="outline" className="gap-2">Export CSV</Button></a>|<a href={`${API_URL}/analytics/export`} target="_blank"><Button variant="outline" className="gap-2">Export CSV</Button></a>\n          <a href={`${API_URL}/analytics/export-pdf`} target="_blank"><Button variant="outline" className="gap-2">Export PDF</Button></a>|' src/app/operations/queue/QueueClient.tsx

echo "4. Updating Command Palette (Cmd+K) for Live Search..."
cat > src/components/layout/app-shell.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Command } from "cmdk";
import { LayoutDashboard, Map, ListTodo, Brain, Settings, Search, Bell, LogOut, ChevronLeft, Menu, FileText } from "lucide-react";
import { getToken, logout, API_URL } from "@/lib/api";
import { useQuery, useQueryClient } from "@tanstack/react-query";

const navigation = [
  { name: "Overview", href: "/operations", icon: LayoutDashboard },
  { name: "Complaint Queue", href: "/operations/queue", icon: ListTodo },
  { name: "Map Operations", href: "/operations/map", icon: Map },
  { name: "Intelligence", href: "/intelligence", icon: Brain },
  { name: "Admin Settings", href: "/admin", icon: Settings },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [open, setOpen] = useState(false);
  const [showNotifs, setShowNotifs] = useState(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  
  const [searchQuery, setSearchQuery] = useState("");
  const { data: searchResults } = useQuery({
    queryKey: ["search", searchQuery],
    queryFn: () => searchQuery.length > 1 ? fetch(`${API_URL}/search/?q=${searchQuery}`, { headers: { Authorization: `Bearer ${getToken()}` }}).then(r => r.json()) : Promise.resolve([]),
    enabled: searchQuery.length > 1
  });

  const { data: notifications } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => fetch(`${API_URL}/notifications/`, { headers: { Authorization: `Bearer ${getToken()}` }}).then(r => r.json())
  });

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); } else { setIsCheckingAuth(false); }
  }, [router]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); setOpen((open) => !open); }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const clearNotifs = async () => {
    await fetch(`${API_URL}/notifications/mark-read`, { method: "POST", headers: { Authorization: `Bearer ${getToken()}` }});
    queryClient.invalidateQueries({ queryKey: ["notifications"] });
    setShowNotifs(false);
  };

  if (isCheckingAuth) return <div className="flex h-screen bg-slate-50 items-center justify-center"><div className="animate-pulse flex space-x-4"><div className="rounded-full bg-slate-200 h-12 w-12"></div></div></div>;

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      <motion.aside animate={{ width: isCollapsed ? 76 : 248 }} className="bg-[#102F35] text-white flex flex-col border-r border-slate-800 relative z-20">
        <div className="h-16 flex items-center justify-between px-4 border-b border-white/10">
          {!isCollapsed && <span className="font-bold tracking-tight text-lg">CIVICLENS</span>}
          <button onClick={() => setIsCollapsed(!isCollapsed)} className="p-1.5 hover:bg-white/10 rounded-md">
            {isCollapsed ? <Menu className="h-5 w-5" /> : <ChevronLeft className="h-5 w-5" />}
          </button>
        </div>
        <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link key={item.name} href={item.href}>
                <div className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${isActive ? 'bg-[#176B61] text-white' : 'text-slate-300 hover:bg-white/5'}`}>
                  <item.icon className="h-5 w-5 shrink-0" />
                  {!isCollapsed && <span className="text-sm font-medium">{item.name}</span>}
                </div>
              </Link>
            );
          })}
        </nav>
        <div className="p-4 border-t border-white/10">
          <button onClick={logout} className="flex items-center gap-3 text-slate-300 hover:text-white w-full px-3 py-2">
            <LogOut className="h-5 w-5 shrink-0" />
            {!isCollapsed && <span className="text-sm font-medium">Sign Out</span>}
          </button>
        </div>
      </motion.aside>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b flex items-center justify-between px-6 shrink-0 z-10">
          <div className="flex items-center gap-4">
            <h1 className="text-lg font-bold text-slate-800 hidden md:block">Municipal Operations</h1>
            <span className="bg-amber-100 text-amber-800 text-xs font-bold px-2.5 py-1 rounded-full border border-amber-200">Hyderabad Pilot</span>
          </div>
          <div className="flex items-center gap-3 relative">
            <button onClick={() => setOpen(true)} className="flex items-center gap-2 px-3 py-1.5 text-sm text-slate-500 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors">
              <Search className="h-4 w-4" /> <span>Search...</span>
            </button>
            
            <div className="relative">
              <button onClick={() => setShowNotifs(!showNotifs)} className="p-2 text-slate-500 hover:bg-slate-100 rounded-full relative">
                <Bell className="h-5 w-5" />
                {notifications?.length > 0 && <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>}
              </button>
              {showNotifs && (
                <div className="absolute right-0 mt-2 w-80 bg-white border shadow-lg rounded-lg overflow-hidden">
                  <div className="p-3 border-b flex justify-between items-center bg-slate-50">
                    <span className="font-bold text-sm">Notifications</span>
                    <button onClick={clearNotifs} className="text-xs text-blue-600 hover:underline">Mark all read</button>
                  </div>
                  <div className="max-h-64 overflow-y-auto">
                    {notifications?.length === 0 ? <p className="p-4 text-sm text-slate-500 text-center">No new notifications</p> : notifications?.map((n: any) => (
                      <div key={n.id} className="p-3 border-b hover:bg-slate-50">
                        <p className="text-sm font-medium text-slate-800">{n.title}</p>
                        <p className="text-xs text-slate-500">{n.message}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
            <div className="h-8 w-8 rounded-full bg-[#176B61] text-white flex items-center justify-center font-bold text-sm">OP</div>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-6 md:p-8">
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
            {children}
          </motion.div>
        </main>
      </div>

      <Command.Dialog open={open} onOpenChange={setOpen} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-xl shadow-2xl border w-full max-w-lg z-50 p-4">
        <Command.Input 
          placeholder="Search reports, refs, or pages..." 
          className="w-full border-none outline-none text-lg p-2 mb-4"
          value={searchQuery}
          onValueChange={setSearchQuery}
        />
        <Command.List className="max-h-[300px] overflow-y-auto">
          <Command.Empty className="text-sm text-slate-500 text-center py-4">No results found.</Command.Empty>
          
          {searchResults && searchResults.length > 0 && (
            <Command.Group heading="Reports" className="text-xs font-bold text-slate-500 mb-2">
              {searchResults.map((r: any) => (
                <Command.Item key={r.id} onSelect={() => { router.push(`/operations/report/${r.id}`); setOpen(false); }} className="p-2 hover:bg-slate-100 rounded-md cursor-pointer text-sm">
                  <div className="flex items-center gap-2">
                    <FileText className="h-4 w-4 text-primary" />
                    <span className="font-mono text-xs">{r.public_ref}</span>
                    <span className="truncate max-w-[200px] text-slate-600">{r.description}</span>
                  </div>
                </Command.Item>
              ))}
            </Command.Group>
          )}

          <Command.Group heading="Navigation" className="text-xs font-bold text-slate-500 mb-2">
            {navigation.map(item => (
              <Command.Item key={item.href} onSelect={() => { router.push(item.href); setOpen(false); }} className="p-2 hover:bg-slate-100 rounded-md cursor-pointer text-sm flex items-center gap-2">
                <item.icon className="h-4 w-4" /> {item.name}
              </Command.Item>
            ))}
          </Command.Group>
        </Command.List>
      </Command.Dialog>
    </div>
  );
}
EOF

echo "5. Writing Playwright Test for PDF & Search..."
cat > tests/batch43.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('PDF Export & Global Search', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
  });

  test('User can search reports via Cmd+K', async ({ page }) => {
    await page.keyboard.press('Meta+k');
    const searchInput = page.locator('input[placeholder="Search reports, refs, or pages..."]');
    await expect(searchInput).toBeVisible();
    
    // Type a known reference
    await searchInput.fill('CL-2026');
    
    // Wait for API and expect results under "Reports"
    await expect(page.locator('text=Reports')).toBeVisible({ timeout: 5000 });
    
    // Click the first report
    await page.locator('[cmdk-item]').first().click();
    await expect(page).toHaveURL(/.*operations\/report\/.*/);
  });

  test('User can download PDF report', async ({ page }) => {
    await page.click('text=Complaint Queue');
    
    // Intercept the PDF download
    const downloadPromise = page.waitForEvent('download');
    await page.click('button:has-text("Export PDF")');
    const download = await downloadPromise;
    
    // Verify filename
    expect(download.suggestedFilename()).toBe('civiclens_report.pdf');
  });
});
EOF

echo "6. Running Automated Test..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch43.spec.ts || TEST_FAILED=true

echo "7. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. PDF Export & Search work."
fi

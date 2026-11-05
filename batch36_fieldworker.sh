#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai

echo "1. Updating Backend: Field Worker tasks and Real Notifications..."
cd apps/api
source ../../.venv/bin/activate

# 1a. Update ops.py to allow field workers to get their tasks, and generate notifications on assign
cat > app/api/ops.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
from ..database import get_db
from ..models.models import Complaint, User, StatusEvent, Assignment, UserRole, Notification
from ..schemas import ComplaintResponse, StatusUpdate, AssignRequest
from ..core.security import get_current_user

router = APIRouter()

def get_current_staff(current_user: User = Depends(get_current_user)):
    if current_user.role not in [UserRole.OPERATOR, UserRole.SUPERVISOR, UserRole.ADMIN]:
        raise HTTPException(status_code=403, detail="Not authorized")
    return current_user

@router.get("/reports", response_model=List[ComplaintResponse])
def get_city_queue(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    return db.query(Complaint).order_by(Complaint.created_at.desc()).all()

@router.get("/my-tasks", response_model=List[ComplaintResponse])
def get_my_tasks(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != UserRole.FIELD_WORKER:
        raise HTTPException(status_code=403, detail="Only field workers can access this")
    
    # Get assignments for this user
    assignments = db.query(Assignment).filter(Assignment.assignee_id == current_user.id).all()
    complaint_ids = [a.complaint_id for a in assignments]
    
    if not complaint_ids:
        return []
        
    return db.query(Complaint).filter(Complaint.id.in_(complaint_ids)).order_by(Complaint.created_at.desc()).all()

@router.post("/reports/{report_id}/assign")
def assign_report(report_id: int, payload: AssignRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    
    assignee = db.query(User).filter(User.id == payload.assignee_id).first()
    if not assignee: raise HTTPException(status_code=404, detail="Assignee not found")

    assignment = Assignment(complaint_id=complaint.id, assignee_id=assignee.id, assigned_by=current_user.id, note=payload.note)
    db.add(assignment)
    
    # Create Notification
    notif = Notification(user_id=assignee.id, title="New Task Assigned", message=f"You have been assigned {complaint.public_ref}.")
    db.add(notif)
    
    if complaint.status.name == "SUBMITTED":
        complaint.status = "ASSIGNED"
        event = StatusEvent(complaint_id=complaint.id, from_status="SUBMITTED", to_status="ASSIGNED", actor_id=current_user.id, note=f"Assigned to {assignee.name}")
        db.add(event)
        
    db.commit()
    return {"message": "Assigned"}

@router.post("/reports/{report_id}/status")
def update_status(report_id: int, payload: StatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    
    # Field workers can only update their own assigned tasks
    if current_user.role == UserRole.FIELD_WORKER:
        assignment = db.query(Assignment).filter(Assignment.complaint_id == report_id, Assignment.assignee_id == current_user.id).first()
        if not assignment:
            raise HTTPException(status_code=403, detail="Not assigned to you")

    old_status = complaint.status
    complaint.status = payload.status
    if payload.status.name == "RESOLVED":
        complaint.resolved_at = datetime.now(timezone.utc)
        
    event = StatusEvent(complaint_id=complaint.id, from_status=old_status, to_status=payload.status, actor_id=current_user.id, note=payload.note)
    db.add(event)
    db.commit()
    return {"message": "Status updated"}
EOF

# 1b. Update notifications API to fetch real data
cat > app/api/notifications.py << 'EOF'
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Notification, User
from ..core.security import get_current_user

router = APIRouter()

@router.get("/")
def get_notifications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    notifs = db.query(Notification).filter(Notification.user_id == current_user.id, Notification.is_read == False).order_by(Notification.created_at.desc()).all()
    return [{"id": n.id, "title": n.title, "message": n.message} for n in notifs]

@router.post("/mark-read")
def mark_read(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db.query(Notification).filter(Notification.user_id == current_user.id).update({"is_read": True})
    db.commit()
    return {"status": "ok"}
EOF

cd ../..

echo "2. Updating Frontend: Notifications in AppShell..."
cd apps/web
cat > src/components/layout/app-shell.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Command } from "cmdk";
import { LayoutDashboard, Map, ListTodo, Brain, Settings, Search, Bell, LogOut, ChevronLeft, Menu } from "lucide-react";
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
        <Command.Input placeholder="Search pages..." className="w-full border-none outline-none text-lg p-2 mb-4" />
        <Command.List className="max-h-[300px] overflow-y-auto">
          <Command.Empty className="text-sm text-slate-500 text-center py-4">No results found.</Command.Empty>
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

echo "3. Creating Field Worker Mobile UI..."
mkdir -p src/app/field
cat > src/app/field/page.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { MapPin, CheckCircle2, LogOut } from "lucide-react";

export default function FieldWorkerTasks() {
  const router = useRouter();
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/my-tasks`, { headers: { Authorization: `Bearer ${token}` }})
      .then(res => {
        if (res.status === 401 || res.status === 403) { logout(); throw new Error("Unauthorized"); }
        return res.json();
      })
      .then(data => { setTasks(data); setLoading(false); })
      .catch(() => logout());
  }, [router]);

  const resolveTask = async (id: number) => {
    const note = prompt("Enter completion notes:");
    if (!note) return;

    await fetch(`${API_URL}/ops/reports/${id}/status`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${getToken()}` },
      body: JSON.stringify({ status: "resolved", note })
    });
    
    // Refresh
    setTasks(tasks.filter(t => t.id !== id));
  };

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="bg-[#102F35] text-white p-4 flex justify-between items-center sticky top-0 z-10 shadow-md">
        <div>
          <h1 className="font-bold text-lg">Field Ops</h1>
          <p className="text-xs text-slate-300">My Assigned Tasks</p>
        </div>
        <button onClick={logout} className="p-2 bg-white/10 rounded-full"><LogOut className="h-5 w-5" /></button>
      </header>

      <main className="p-4 space-y-4 max-w-lg mx-auto">
        {loading ? <p className="text-center text-slate-500 mt-10">Loading tasks...</p> : tasks.length === 0 ? (
          <div className="text-center mt-10 p-6 bg-white rounded-xl shadow-sm border">
            <CheckCircle2 className="h-12 w-12 text-green-500 mx-auto mb-3" />
            <h2 className="font-bold text-lg">All caught up!</h2>
            <p className="text-slate-500 text-sm">You have no pending tasks.</p>
          </div>
        ) : tasks.map(task => (
          <div key={task.id} className="bg-white rounded-xl border shadow-sm overflow-hidden">
            <div className="p-4 border-b">
              <div className="flex justify-between items-start mb-2">
                <span className="font-mono text-xs text-slate-500">{task.public_ref}</span>
                <Badge variant={task.status === 'ASSIGNED' ? 'default' : 'secondary'}>{task.status.toUpperCase()}</Badge>
              </div>
              <h3 className="font-bold text-slate-900">{task.category.replace('_', ' ').toUpperCase()}</h3>
              <p className="text-sm text-slate-600 mt-1">{task.description}</p>
            </div>
            <div className="p-4 bg-slate-50 flex items-center justify-between">
              <a href={`https://www.google.com/maps?q=${task.lat},${task.lon}`} target="_blank" rel="noreferrer" className="flex items-center text-sm text-blue-600 font-medium">
                <MapPin className="h-4 w-4 mr-1" /> Navigate
              </a>
              <Button size="sm" onClick={() => resolveTask(task.id)}>Mark Resolved</Button>
            </div>
          </div>
        ))}
      </main>
    </div>
  );
}
EOF

echo "4. Updating Login Redirect for Field Workers..."
cat > src/app/login/page.tsx << 'EOF'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL, setToken } from "@/lib/api";
import { jwtDecode } from "jwt-decode";

export default function Login() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(""); setLoading(true);
    try {
      const formData = new URLSearchParams();
      formData.append("username", email);
      formData.append("password", password);

      const res = await fetch(`${API_URL}/auth/login`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: formData });
      if (!res.ok) throw new Error("Invalid credentials");
      
      const data = await res.json();
      setToken(data.access_token);
      
      const decoded: any = jwtDecode(data.access_token);
      if (decoded.role === "citizen") router.push("/dashboard");
      else if (decoded.role === "field_worker") router.push("/field");
      else router.push("/operations");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const fillCitizen = () => { setEmail("citizen@example.com"); setPassword("password123"); };
  const fillOperator = () => { setEmail("operator@civiclens.ai"); setPassword("password123"); };
  const fillWorker = () => { setEmail("worker@civiclens.ai"); setPassword("password123"); };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
      <div className="w-full max-w-md p-8 bg-white rounded-xl border shadow-sm">
        <div className="text-center mb-8">
          <div className="mx-auto h-12 w-12 rounded bg-[#176B61] flex items-center justify-center text-white font-bold text-xl mb-4">C</div>
          <h2 className="text-2xl font-bold text-slate-900">Sign In to CIVICLENS</h2>
        </div>

        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
        
        <form onSubmit={handleLogin} className="space-y-4">
          <input type="email" className="w-full p-2 border rounded-md" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" required />
          <input type="password" className="w-full p-2 border rounded-md" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" required />
          <Button type="submit" className="w-full" disabled={loading}>{loading ? "Signing In..." : "Sign In"}</Button>
        </form>

        <div className="mt-8 pt-6 border-t">
          <p className="text-xs text-center text-slate-500 font-medium mb-3 uppercase tracking-wider">Demo Shortcuts</p>
          <div className="grid grid-cols-3 gap-2">
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillCitizen}>Citizen</Button>
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillOperator}>Operator</Button>
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillWorker}>Worker</Button>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "5. Writing Playwright Test for Field Worker..."
cat > tests/batch36.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Field Worker Journey & Notifications', () => {

  test('Operator assigns task, Worker receives notification and resolves it', async ({ page }) => {
    // 1. Operator Logs in and assigns
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*operations/);
    
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    
    // Assign to first worker (Field Worker 1)
    await page.selectOption('select >> nth=0', { index: 1 });
    await page.click('button:has-text("Assign Worker")');
    await page.waitForTimeout(1000); // wait for API

    // 2. Field Worker Logs in
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*field/);

    // Worker sees task and resolves
    await expect(page.locator('body')).toContainText('My Assigned Tasks');
    const resolveBtn = page.locator('button:has-text("Mark Resolved")').first();
    await expect(resolveBtn).toBeVisible();
    
    // Handle prompt
    page.on('dialog', async dialog => {
      expect(dialog.message()).toContain('Enter completion notes');
      await dialog.accept('Fixed the pothole with new asphalt.');
    });
    await resolveBtn.click();
    
    await expect(page.locator('body')).toContainText('All caught up!');
  });
});
EOF

echo "6. Running Playwright..."
cd ../..
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd apps/api && source ../../.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd ../web && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

npx playwright test tests/batch36.spec.ts

echo "7. Committing..."
cd ~/Desktop/civiclens-ai
git add .
git commit -m "feat(enterprise): field worker mobile UI, app notifications, and automated tests"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Batch 36 Complete. Field Worker UI & Notifications verified."
echo "============================================================"

#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Adding a Field Worker to the database..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -c "
from app.database import SessionLocal
from app.models.models import User, UserRole
from app.core.security import get_password_hash
db = SessionLocal()
if not db.query(User).filter(User.email == 'worker@civiclens.ai').first():
    w = User(email='worker@civiclens.ai', name='Field Worker 1', password_hash=get_password_hash('password123'), role=UserRole.FIELD_WORKER)
    db.add(w)
    db.commit()
    print('Field worker created.')
else:
    print('Field worker already exists.')
"
cd ../..

# 1. Update Backend Ops API
cat >> apps/api/app/api/ops.py << 'EOF'

@router.get("/reports/{report_id}", response_model=ComplaintResponse)
def get_report(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
    return complaint

@router.get("/workers")
def get_workers(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    workers = db.query(User).filter(User.role == UserRole.FIELD_WORKER).all()
    return [{"id": w.id, "name": w.name} for w in workers]
EOF

# 2. Frontend: Install jwt-decode
cd apps/web
npm install jwt-decode

# 3. Update Login Page to handle Role-based redirect
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

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const formData = new URLSearchParams();
      formData.append("username", email);
      formData.append("password", password);

      const res = await fetch(`${API_URL}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: formData,
      });

      if (!res.ok) throw new Error("Invalid credentials");
      
      const data = await res.json();
      setToken(data.access_token);
      
      // Decode token to check role
      const decoded: any = jwtDecode(data.access_token);
      if (decoded.role === "citizen") {
        router.push("/dashboard");
      } else {
        router.push("/operations");
      }
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50">
      <div className="w-full max-w-md p-8 bg-white rounded-xl border shadow-sm">
        <h2 className="text-2xl font-bold mb-6 text-center text-slate-900">Sign In to CIVICLENS</h2>
        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input 
              type="email" 
              className="w-full p-2 border rounded-md" 
              value={email} onChange={(e) => setEmail(e.target.value)} 
              placeholder="operator@civiclens.ai" required 
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input 
              type="password" 
              className="w-full p-2 border rounded-md" 
              value={password} onChange={(e) => setPassword(e.target.value)} 
              placeholder="password123" required 
            />
          </div>
          <Button type="submit" className="w-full">Sign In</Button>
        </form>
      </div>
    </div>
  );
}
EOF

# 4. Create Operations Dashboard
mkdir -p src/app/operations
cat > src/app/operations/page.tsx << 'EOF'
"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { LogOut, Search } from "lucide-react";
import Link from "next/link";

export default function OperationsDashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/reports`, {
      headers: { "Authorization": `Bearer ${token}` }
    })
      .then(res => {
        if (!res.ok) throw new Error("Unauthorized");
        return res.json();
      })
      .then(data => {
        setReports(data);
        setLoading(false);
      })
      .catch(err => logout());
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <div className="flex items-center gap-2">
          <span className="font-bold text-xl tracking-tight text-primary">CIVICLENS</span>
          <Badge variant="secondary" className="ml-2">Operations Portal</Badge>
        </div>
        <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4 mr-2"/> Sign Out</Button>
      </header>

      <main className="flex-1 max-w-7xl w-full mx-auto py-8 px-6">
        <div className="flex justify-between items-end mb-8">
          <div>
            <h1 className="text-3xl font-bold text-slate-900">City Queue</h1>
            <p className="text-slate-500 mt-1">Manage and dispatch all reported issues across the city.</p>
          </div>
          <div className="flex gap-2">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-slate-500" />
              <input type="text" placeholder="Search reports..." className="pl-9 p-2 border rounded-md text-sm w-64" />
            </div>
          </div>
        </div>
        
        {loading ? (
          <p className="text-slate-500">Loading queue...</p>
        ) : (
          <div className="bg-white border rounded-xl overflow-hidden shadow-sm">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-100 border-b">
                <tr>
                  <th className="px-6 py-3 font-medium text-slate-600">Ref ID</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Category</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Description</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Status</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Priority</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Date</th>
                  <th className="px-6 py-3 font-medium text-slate-600 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((r) => (
                  <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                    <td className="px-6 py-4 font-mono text-slate-500">{r.public_ref}</td>
                    <td className="px-6 py-4 font-medium">{r.category.replace('_', ' ').toUpperCase()}</td>
                    <td className="px-6 py-4 truncate max-w-xs">{r.description}</td>
                    <td className="px-6 py-4">
                      <Badge variant={r.status === 'resolved' ? 'default' : 'secondary'}>
                        {r.status.replace('_', ' ').toUpperCase()}
                      </Badge>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`font-medium ${r.priority === 'Critical' ? 'text-red-600' : r.priority === 'High' ? 'text-amber-600' : 'text-slate-600'}`}>
                        {r.priority}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-500">{new Date(r.created_at).toLocaleDateString()}</td>
                    <td className="px-6 py-4 text-right">
                      <Link href={`/operations/report/${r.id}`}>
                        <Button variant="outline" size="sm">Manage</Button>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}
EOF

# 5. Create Operations Report Detail Page
mkdir -p src/app/operations/report/\[id\]
cat > src/app/operations/report/\[id\]/page.tsx << 'EOF'
"use client";
import { useEffect, useState, use } from "react";
import { useRouter, useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft, MapPin, CheckCircle2 } from "lucide-react";
import Link from "next/link";

export default function ReportDetail() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  
  const [report, setReport] = useState<any>(null);
  const [workers, setWorkers] = useState<any[]>([]);
  const [selectedWorker, setSelectedWorker] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);

  const fetchData = async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    try {
      const [repRes, workRes] = await Promise.all([
        fetch(`${API_URL}/ops/reports/${id}`, { headers: { "Authorization": `Bearer ${token}` } }),
        fetch(`${API_URL}/ops/workers`, { headers: { "Authorization": `Bearer ${token}` } })
      ]);
      if (!repRes.ok) throw new Error("Not found");
      
      const repData = await repRes.json();
      const workData = await workRes.json();
      
      setReport(repData);
      setWorkers(workData);
      setNewStatus(repData.status);
      setLoading(false);
    } catch (err) {
      logout();
    }
  };

  useEffect(() => { fetchData(); }, [id]);

  const handleAssign = async () => {
    if (!selectedWorker) return;
    setActionLoading(true);
    const token = getToken();
    await fetch(`${API_URL}/ops/reports/${id}/assign`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
      body: JSON.stringify({ assignee_id: parseInt(selectedWorker), note: "Assigned via Ops Portal" })
    });
    await fetchData();
    setActionLoading(false);
    setSelectedWorker("");
  };

  const handleUpdateStatus = async () => {
    setActionLoading(true);
    const token = getToken();
    await fetch(`${API_URL}/ops/reports/${id}/status`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${token}` },
      body: JSON.stringify({ status: newStatus, note: "Status updated via Ops Portal" })
    });
    await fetchData();
    setActionLoading(false);
  };

  if (loading || !report) return <div className="p-10 text-center">Loading...</div>;

  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <div className="max-w-4xl mx-auto">
        <Link href="/operations" className="flex items-center text-slate-500 hover:text-primary mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" /> Back to Queue
        </Link>
        
        <div className="grid grid-cols-3 gap-6">
          {/* Main Details */}
          <div className="col-span-2 space-y-6">
            <div className="bg-white p-8 rounded-xl border shadow-sm">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <span className="font-mono text-sm text-slate-500">{report.public_ref}</span>
                  <h1 className="text-2xl font-bold mt-1">{report.category.replace('_', ' ').toUpperCase()}</h1>
                </div>
                <Badge variant={report.status === 'resolved' ? 'default' : 'secondary'} className="text-sm px-3 py-1">
                  {report.status.toUpperCase()}
                </Badge>
              </div>
              <p className="text-slate-700 text-lg mb-6">{report.description}</p>
              
              <div className="bg-slate-50 p-4 rounded-lg flex items-center gap-4 text-sm text-slate-600">
                <MapPin className="h-5 w-5 text-primary" />
                Location: {report.lat.toFixed(6)}, {report.lon.toFixed(6)}
              </div>
            </div>
          </div>

          {/* Action Sidebar */}
          <div className="space-y-6">
            {/* Assign Worker */}
            <div className="bg-white p-6 rounded-xl border shadow-sm">
              <h3 className="font-bold mb-4">Assign to Field Worker</h3>
              <select className="w-full p-2 border rounded-md mb-3 text-sm" value={selectedWorker} onChange={(e) => setSelectedWorker(e.target.value)}>
                <option value="">Select a worker...</option>
                {workers.map(w => <option key={w.id} value={w.id}>{w.name}</option>)}
              </select>
              <Button className="w-full" onClick={handleAssign} disabled={!selectedWorker || actionLoading}>
                Assign Worker
              </Button>
            </div>

            {/* Update Status */}
            <div className="bg-white p-6 rounded-xl border shadow-sm">
              <h3 className="font-bold mb-4">Update Status</h3>
              <select className="w-full p-2 border rounded-md mb-3 text-sm" value={newStatus} onChange={(e) => setNewStatus(e.target.value)}>
                <option value="submitted">Submitted</option>
                <option value="acknowledged">Acknowledged</option>
                <option value="assigned">Assigned</option>
                <option value="in_progress">In Progress</option>
                <option value="resolved">Resolved</option>
                <option value="closed">Closed</option>
                <option value="rejected">Rejected</option>
              </select>
              <Button className="w-full gap-2" variant="secondary" onClick={handleUpdateStatus} disabled={actionLoading}>
                <CheckCircle2 className="h-4 w-4" /> Update Status
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

# 6. Build to verify
echo "Building frontend with ops pages..."
npm run build

cd ~/Desktop/civiclens-ai

# 7. Commit and push
echo "Committing Batch 7 to Git..."
git add .
git commit -m "feat(batch7): operations dashboard, assignment, and status updates UI"
git push -u origin main

# 8. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch7-complete
last_batch: 7
frontend: Operations UI working (Queue, Assign, Update Status)
next_action: batch8-maps-and-analytics
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 7 Complete!"
echo "Operations Portal is fully built."
echo "============================================================"

#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Restoring the missing /workers endpoint in ops.py..."
# Append the missing endpoint to the existing ops.py
cat >> $API_DIR/app/api/ops.py << 'EOF'

@router.get("/workers")
def get_workers(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    workers = db.query(User).filter(User.role == UserRole.FIELD_WORKER).all()
    return [{"id": w.id, "name": w.name} for w in workers]
EOF

echo "2. Fixing the Frontend ReportDetail to handle API errors gracefully..."
cat > $WEB_DIR/src/app/operations/report/\[id\]/page.tsx << 'EOF'
"use client";
import { useEffect, useState, Suspense } from "react";
import { useRouter, useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft, MapPin, CheckCircle2 } from "lucide-react";
import Link from "next/link";

function ReportContent() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  
  const [report, setReport] = useState<any>(null);
  const [workers, setWorkers] = useState<any[]>([]);
  const [selectedWorker, setSelectedWorker] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState("");

  const fetchData = async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    try {
      const [repRes, workRes] = await Promise.all([
        fetch(`${API_URL}/ops/reports/${id}`, { headers: { "Authorization": `Bearer ${token}` } }),
        fetch(`${API_URL}/ops/workers`, { headers: { "Authorization": `Bearer ${token}` } })
      ]);
      
      if (repRes.status === 401 || workRes.status === 401) { logout(); return; }
      if (!repRes.ok) throw new Error("Report not found");
      
      const repData = await repRes.json();
      // Safely handle workers array
      const workData = workRes.ok ? await workRes.json() : [];
      
      setReport(repData);
      setWorkers(Array.isArray(workData) ? workData : []);
      setNewStatus(repData.status);
      setLoading(false);
    } catch (err) {
      setError("Could not load report data.");
      setLoading(false);
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

  if (loading) return <div className="p-10 text-center text-slate-500">Loading report details...</div>;
  if (error || !report) return <div className="p-10 text-center text-red-500">{error}</div>;

  return (
    <div className="max-w-4xl mx-auto">
      <Link href="/operations/queue" className="flex items-center text-slate-500 hover:text-primary mb-6">
        <ArrowLeft className="h-4 w-4 mr-2" /> Back to Queue
      </Link>
      
      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-2 space-y-6">
          <div className="bg-white p-8 rounded-xl border shadow-sm">
            <div className="flex justify-between items-start mb-4">
              <div>
                <span className="font-mono text-sm text-slate-500">{report.public_ref}</span>
                <h1 className="text-2xl font-bold mt-1">{report.category.replace('_', ' ').toUpperCase()}</h1>
              </div>
              <Badge variant={report.status === 'RESOLVED' ? 'default' : 'secondary'} className="text-sm px-3 py-1">
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

        <div className="space-y-6">
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
  );
}

export default function ReportDetail() {
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <Suspense fallback={<div className="p-10 text-center">Loading...</div>}>
        <ReportContent />
      </Suspense>
    </div>
  );
}
EOF

echo "3. Cleaning up old servers..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

echo "4. Starting Backend API..."
cd $API_DIR
source $ROOT/.venv/bin/activate
uvicorn app.main:app > /tmp/api.log 2>&1 &
BACKEND_PID=$!

echo "5. Starting Frontend UI..."
cd $WEB_DIR
npm run dev -- --webpack > /tmp/web.log 2>&1 &
FRONTEND_PID=$!

echo "6. Waiting for servers to boot..."
for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then
        echo "✅ Servers are up!"
        break
    fi
    sleep 1
done

echo "7. Running Playwright Browser Test..."
cd $WEB_DIR
npx playwright test tests/batch36.spec.ts || TEST_FAILED=true

echo "8. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "============================================================"
    echo "❌ TEST FAILED."
    echo "============================================================"
    exit 1
else
    echo "============================================================"
    echo "✅ TEST PASSED SUCCESSFULLY. Field Worker UI & Notifications work."
    echo "============================================================"
fi

#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
WEB_DIR=$ROOT/apps/web
API_DIR=$ROOT/apps/api

echo "1. Fixing Next.js 16 dynamic params in Report Detail..."
mkdir -p $WEB_DIR/src/app/operations/report/\[id\]
cat > $WEB_DIR/src/app/operations/report/\[id\]/page.tsx << 'EOF'
"use client";
import { use, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft, MapPin, CheckCircle2 } from "lucide-react";
import Link from "next/link";

function ReportContent({ id }: { id: string }) {
  const router = useRouter();
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

export default function ReportDetail({ params }: { params: Promise<{ id: string }> }) {
  const { id } = use(params);
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <ReportContent id={id} />
    </div>
  );
}
EOF

echo "2. Updating Playwright Test with better waiting logic..."
cat > $WEB_DIR/tests/batch36.spec.ts << 'EOF'
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
    await page.waitForURL(/.*operations\/report\/.*/);
    
    // WAIT FOR THE DROPDOWN TO APPEAR
    try {
      await page.waitForSelector('select', { timeout: 5000 });
    } catch (e) {
      console.log("PAGE CONTENT ON FAILURE:", await page.locator('body').innerText());
      throw e;
    }
    
    // Assign to first worker (Field Worker 1)
    await page.selectOption('select >> nth=0', { index: 1 });
    await page.click('button:has-text("Assign Worker")');
    await page.waitForTimeout(1000); 

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

echo "3. Starting Servers & Running Automated Test..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch36.spec.ts || TEST_FAILED=true

echo "4. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Field Worker UI & Notifications work."
fi

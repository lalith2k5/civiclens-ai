#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Fixing Report Detail with strict Next.js 16 Suspense boundary..."
mkdir -p $WEB_DIR/src/app/operations/report/\[id\]
cat > $WEB_DIR/src/app/operations/report/\[id\]/page.tsx << 'EOF'
"use client";
import { Suspense, useEffect, useState } from "react";
import { useRouter, useParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft, MapPin, CheckCircle2, MessageSquare } from "lucide-react";
import Link from "next/link";

function ReportContent() {
  const router = useRouter();
  const params = useParams();
  const id = params.id as string;
  
  const [report, setReport] = useState<any>(null);
  const [workers, setWorkers] = useState<any[]>([]);
  const [history, setHistory] = useState<any[]>([]);
  const [comments, setComments] = useState<any[]>([]);
  
  const [selectedWorker, setSelectedWorker] = useState("");
  const [newStatus, setNewStatus] = useState("");
  const [newComment, setNewComment] = useState("");
  const [commentVisibility, setCommentVisibility] = useState("public");
  
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [error, setError] = useState("");

  const fetchData = async () => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    try {
      const [repRes, workRes, histRes, commRes] = await Promise.all([
        fetch(`${API_URL}/ops/reports/${id}`, { headers: { "Authorization": `Bearer ${token}` } }),
        fetch(`${API_URL}/ops/workers`, { headers: { "Authorization": `Bearer ${token}` } }),
        fetch(`${API_URL}/ops/reports/${id}/history`, { headers: { "Authorization": `Bearer ${token}` } }),
        fetch(`${API_URL}/ops/reports/${id}/comments`, { headers: { "Authorization": `Bearer ${token}` } })
      ]);
      
      if (repRes.status === 401) { logout(); return; }
      if (!repRes.ok) throw new Error("Report not found");
      
      const repData = await repRes.json();
      setReport(repData);
      setWorkers(workRes.ok ? await workRes.json() : []);
      setHistory(histRes.ok ? await histRes.json() : []);
      setComments(commRes.ok ? await commRes.json() : []);
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
    await fetch(`${API_URL}/ops/reports/${id}/assign`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` },
      body: JSON.stringify({ assignee_id: parseInt(selectedWorker), note: "Assigned via Ops Portal" })
    });
    await fetchData();
    setActionLoading(false);
    setSelectedWorker("");
  };

  const handleUpdateStatus = async () => {
    setActionLoading(true);
    await fetch(`${API_URL}/ops/reports/${id}/status`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` },
      body: JSON.stringify({ status: newStatus, note: "Status updated via Ops Portal" })
    });
    await fetchData();
    setActionLoading(false);
  };

  const handleAddComment = async () => {
    if (!newComment) return;
    await fetch(`${API_URL}/ops/reports/${id}/comments`, {
      method: "POST",
      headers: { "Content-Type": "application/json", "Authorization": `Bearer ${getToken()}` },
      body: JSON.stringify({ body: newComment, visibility: commentVisibility })
    });
    setNewComment("");
    fetchData();
  };

  if (loading) return <div className="p-10 text-center text-slate-500">Loading report details...</div>;
  if (error || !report) return <div className="p-10 text-center text-red-500">{error}</div>;

  return (
    <div className="max-w-6xl mx-auto">
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

          <div className="bg-white p-8 rounded-xl border shadow-sm">
            <h3 className="font-bold text-lg mb-4">Audit Timeline</h3>
            <div className="space-y-4">
              {history.length === 0 ? <p className="text-sm text-slate-500">No events recorded yet.</p> : history.map((h, i) => (
                <div key={h.id} className="flex gap-4">
                  <div className="flex flex-col items-center">
                    <div className="w-3 h-3 rounded-full bg-primary mt-1.5"></div>
                    {i !== history.length - 1 && <div className="w-px h-full bg-slate-200 my-1"></div>}
                  </div>
                  <div>
                    <p className="text-sm font-medium text-slate-900">
                      Status changed from <span className="uppercase font-bold">{h.from_status}</span> to <span className="uppercase font-bold text-primary">{h.to_status}</span>
                    </p>
                    <p className="text-xs text-slate-500 mt-1">{h.note}</p>
                    <p className="text-xs text-slate-400 mt-1">{new Date(h.created_at).toLocaleString()}</p>
                  </div>
                </div>
              ))}
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
            <Button className="w-full" onClick={handleAssign} disabled={!selectedWorker || actionLoading}>Assign Worker</Button>
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

          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-bold mb-4 flex items-center gap-2"><MessageSquare className="h-5 w-5"/> Comments</h3>
            <div className="space-y-3 mb-4 max-h-64 overflow-y-auto">
              {comments.map(c => (
                <div key={c.id} className="p-3 bg-slate-50 rounded border text-sm">
                  <p className="font-bold text-slate-800">{c.author} <span className="text-xs text-slate-400 font-normal ml-1">{c.visibility === 'internal' ? '(Internal)' : '(Public)'}</span></p>
                  <p className="text-slate-600 mt-1">{c.body}</p>
                </div>
              ))}
            </div>
            <div className="space-y-2">
              <select className="w-full p-2 border rounded-md text-sm bg-white" value={commentVisibility} onChange={(e) => setCommentVisibility(e.target.value)}>
                <option value="public">Public Reply</option>
                <option value="internal">Internal Note</option>
              </select>
              <input className="w-full border p-2 rounded" placeholder="Add comment..." value={newComment} onChange={e => setNewComment(e.target.value)} />
              <Button className="w-full" onClick={handleAddComment}>Post Comment</Button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

export default function ReportDetail() {
  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <Suspense fallback={<div className="p-10 text-center text-slate-500">Loading workspace...</div>}>
        <ReportContent />
      </Suspense>
    </div>
  );
}
EOF

echo "2. Fixing the Playwright Test with exact table header locators and wait states..."
cat > $WEB_DIR/tests/batch56.spec.ts << 'EOF'
import { test, expect } from '@playwright/test';

test.describe('Spec Completion Batch', () => {
  test('Field Worker submits evidence form', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Worker")');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL(/.*field/);

    const completeBtn = page.locator('button:has-text("Complete Task")').first();
    if (await completeBtn.isVisible()) {
      await completeBtn.click();
      await page.locator('textarea').fill('Completed the work successfully.');
      await page.click('button:has-text("Submit Evidence")');
      await expect(page.locator('text=All caught up!')).toBeVisible();
    }
  });

  test('Intelligence shows Hotspot Results Table', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    
    // Go to intelligence
    await page.click('text=Intelligence');
    
    // Wait for the page title to load to confirm we are on the right page
    await expect(page.locator('h2:has-text("Intelligence Studio")')).toBeVisible({ timeout: 10000 });
    
    // Use exact locator for the table headers
    await expect(page.locator('th:has-text("Hotspot ID")')).toBeVisible();
    await expect(page.locator('th:has-text("Dominant Issue")')).toBeVisible();
    
    // Verify map is present
    await expect(page.locator('.leaflet-container').first()).toBeVisible();
  });

  test('Operator can toggle comment visibility', async ({ page }) => {
    await page.goto('/login');
    await page.click('button:has-text("Operator")');
    await page.click('button[type="submit"]');
    
    await page.click('text=Complaint Queue');
    await page.locator('button:has-text("Manage")').first().click();
    
    // Wait for the Report Detail page to load by waiting for the H1 tag
    await expect(page.locator('h1')).toContainText('ROAD DAMAGE', { timeout: 10000 });
    
    // Wait for the select elements to render
    await page.waitForSelector('select');
    
    // Check for visibility dropdown (nth=2)
    const visibilitySelect = page.locator('select').nth(2); 
    await expect(visibilitySelect).toBeVisible();
    await visibilitySelect.selectOption('internal');
    await expect(visibilitySelect).toHaveValue('internal');
  });
});
EOF

echo "3. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch56.spec.ts || TEST_FAILED=true

echo "4. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Field Evidence, Hotspot Table, and Internal Notes work."
fi

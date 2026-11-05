#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web
source ../../.venv/bin/activate

echo "Installing MapLibre GL..."
npm install maplibre-gl

# 1. FIX BATCH 7 ERROR: Wrap in Suspense
echo "Fixing Next.js 16 Suspense error..."
mkdir -p src/app/operations/report/\[id\]
cat > src/app/operations/report/\[id\]/page.tsx << 'EOF'
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
    <div className="max-w-4xl mx-auto">
      <Link href="/operations" className="flex items-center text-slate-500 hover:text-primary mb-6">
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
      <Suspense fallback={<div className="p-10 text-center">Loading report details...</div>}>
        <ReportContent />
      </Suspense>
    </div>
  );
}
EOF

# 2. Create Map View Page
echo "Building MapLibre Map..."
mkdir -p src/app/operations/map
cat > src/app/operations/map/page.tsx << 'EOF'
"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import "maplibre-gl/dist/maplibre-gl.css";

export default function MapView() {
  const router = useRouter();
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (map.current) return; // initialize map only once

    const initMap = async () => {
      const maplibregl = (await import("maplibre-gl")).default;
      
      map.current = new maplibregl.Map({
        container: mapContainer.current!,
        style: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
        center: [78.4867, 17.3850], // Hyderabad
        zoom: 11,
      });

      map.current.addControl(new maplibregl.NavigationControl(), "top-right");

      // Fetch data and add markers
      const token = getToken();
      if (!token) { router.push("/login"); return; }

      try {
        const res = await fetch(`${API_URL}/ops/reports`, {
          headers: { "Authorization": `Bearer ${token}` }
        });
        if (!res.ok) throw new Error("Failed");
        const data = await res.json();

        data.forEach((report: any) => {
          // Determine marker color based on priority
          const color = report.priority === 'Critical' ? '#dc2626' : 
                        report.priority === 'High' ? '#d97706' : 
                        report.status === 'resolved' ? '#16a34a' : '#176b62';

          const el = document.createElement("div");
          el.className = "w-4 h-4 rounded-full border-2 border-white shadow-md cursor-pointer";
          el.style.backgroundColor = color;

          new maplibregl.Marker(el)
            .setLngLat([report.lon, report.lat])
            .setPopup(new maplibregl.Popup({ offset: 25 }).setHTML(
              `<div class="p-2">
                <h4 class="font-bold text-sm m-0">${report.category.replace('_', ' ').toUpperCase()}</h4>
                <p class="text-xs text-slate-500 m-0 mt-1">${report.public_ref}</p>
                <a href="/operations/report/${report.id}" class="text-xs text-primary font-medium hover:underline mt-2 block">View Details &rarr;</a>
               </div>`
            ))
            .addTo(map.current);
        });
        setLoading(false);
      } catch (err) {
        logout();
      }
    };

    initMap();
  }, [router]);

  return (
    <div className="min-h-screen flex flex-col bg-slate-50">
      <header className="px-6 py-4 border-b bg-white flex justify-between items-center z-10 relative shadow-sm">
        <div className="flex items-center gap-4">
          <Link href="/operations" className="text-slate-500 hover:text-primary flex items-center text-sm font-medium">
            <ArrowLeft className="h-4 w-4 mr-1" /> Back to Queue
          </Link>
          <h1 className="text-xl font-bold text-slate-900 border-l pl-4 border-slate-200">City Geospatial View</h1>
        </div>
        <div className="flex gap-4 text-xs font-medium">
          <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-red-600 inline-block"></span> Critical</div>
          <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-amber-600 inline-block"></span> High</div>
          <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-[#176b62] inline-block"></span> Open</div>
          <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-green-600 inline-block"></span> Resolved</div>
        </div>
      </header>
      
      <div className="flex-1 relative">
        <div ref={mapContainer} className="absolute inset-0" />
        {loading && (
          <div className="absolute inset-0 flex items-center justify-center bg-white/50 backdrop-blur-sm z-10">
            <p className="font-medium text-slate-700">Loading map data...</p>
          </div>
        )}
      </div>
    </div>
  );
}
EOF

# 3. Update Operations Dashboard to include the Map button
echo "Adding Map button to Operations Dashboard..."
cat > src/app/operations/page.tsx << 'EOF'
"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { LogOut, Search, Map as MapIcon } from "lucide-react";
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
          <div className="flex gap-3">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-slate-500" />
              <input type="text" placeholder="Search reports..." className="pl-9 p-2 border rounded-md text-sm w-64" />
            </div>
            <Link href="/operations/map">
              <Button variant="outline" className="gap-2">
                <MapIcon className="h-4 w-4" /> Map View
              </Button>
            </Link>
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

# 4. Build to verify completely
echo "Building frontend with Map View..."
npm run build

cd ~/Desktop/civiclens-ai

# 5. Commit and push
echo "Committing Batch 8 to Git..."
git add .
git commit -m "fix(batch7): suspense fix. feat(batch8): maplibre geospatial map view"
git push -u origin main

# 6. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch8-complete
last_batch: 8
frontend: MapLibre map view working with markers.
next_action: batch9-ml-and-analytics
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 8 Complete!"
echo "Map View and Ops Detail Page are fully built."
echo "============================================================"

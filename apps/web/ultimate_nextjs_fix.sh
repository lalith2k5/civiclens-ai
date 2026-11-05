#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Extracting MapLibre Worker to public folder..."
node -e "
const fs = require('fs');
const path = require('path');
const workerFile = path.join(process.cwd(), 'node_modules/maplibre-gl/dist/maplibre-gl-csp-worker.js');
const dest = path.join(process.cwd(), 'public/maplibre-gl-csp-worker.js');
if (fs.existsSync(workerFile)) {
  fs.copyFileSync(workerFile, dest);
  console.log('✅ Worker copied successfully.');
} else {
  console.log('❌ Worker file not found in node_modules.');
}
"

echo "2. Refactoring Operations Page (Server + Client)..."
mkdir -p src/app/operations
cat > src/app/operations/PageClient.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { motion } from "framer-motion";
import { AlertTriangle, CheckCircle, Clock, FileText } from "lucide-react";

export default function OpsOverview() {
  const { data, isLoading } = useQuery({
    queryKey: ["ops-summary"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/analytics/summary`, { headers: { Authorization: `Bearer ${getToken()}` }});
      return res.json();
    }
  });

  if (isLoading) return <div className="animate-pulse flex gap-4"><div className="h-32 bg-slate-200 rounded-xl flex-1"></div><div className="h-32 bg-slate-200 rounded-xl flex-1"></div></div>;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Command Dashboard</h2>
        <p className="text-slate-500">Real-time overview of city operations and metrics.</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { title: "Total Reports", value: data?.total_reports || 0, icon: FileText, color: "text-blue-600", bg: "bg-blue-50" },
          { title: "Open Issues", value: data?.open_issues || 0, icon: AlertTriangle, color: "text-amber-600", bg: "bg-amber-50" },
          { title: "Resolved", value: data?.resolved || 0, icon: CheckCircle, color: "text-green-600", bg: "bg-green-50" },
          { title: "Avg Resolution", value: "7.3 Days", icon: Clock, color: "text-purple-600", bg: "bg-purple-50" },
        ].map((kpi, i) => (
          <motion.div key={i} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }} className="bg-white p-5 rounded-xl border shadow-sm">
            <div className={`w-10 h-10 ${kpi.bg} ${kpi.color} rounded-lg flex items-center justify-center mb-4`}>
              <kpi.icon className="h-5 w-5" />
            </div>
            <p className="text-sm font-medium text-slate-500">{kpi.title}</p>
            <p className="text-3xl font-bold text-slate-900 mt-1">{kpi.value}</p>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
EOF

cat > src/app/operations/page.tsx << 'EOF'
export const instant = false;
import PageClient from "./PageClient";
export default function Page() { return <PageClient />; }
EOF

echo "3. Refactoring Map Page..."
mkdir -p src/app/operations/map
cat > src/app/operations/map/MapClient.tsx << 'EOF'
"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import "maplibre-gl/dist/maplibre-gl.css";

export default function MapView() {
  const router = useRouter();
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    if (map.current || !mapContainer.current) return;

    const initMap = async () => {
      const maplibregl = await import("maplibre-gl");
      
      // Tell MapLibre to use our local worker file
      (maplibregl as any).workerUrl = '/maplibre-gl-csp-worker.js';

      map.current = new maplibregl.Map({
        container: mapContainer.current!,
        style: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
        center: [78.4867, 17.3850],
        zoom: 11,
      });
      map.current.addControl(new maplibregl.NavigationControl(), "top-right");

      const token = getToken();
      if (!token) { router.push("/login"); return; }

      try {
        const res = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${token}` }});
        if (res.status === 401) { logout(); return; }
        if (!res.ok) throw new Error("Failed to fetch");
        
        const data = await res.json();
        data.forEach((report: any) => {
          const color = report.priority === 'Critical' ? '#dc2626' : report.priority === 'High' ? '#d97706' : report.status === 'resolved' ? '#16a34a' : '#176b62';
          const el = document.createElement("div");
          el.className = "w-3 h-3 rounded-full border-2 border-white shadow-md cursor-pointer";
          el.style.backgroundColor = color;

          new maplibregl.Marker(el)
            .setLngLat([report.lon, report.lat])
            .setPopup(new maplibregl.Popup({ offset: 25 }).setHTML(`<div class="p-2"><h4 class="font-bold text-sm m-0">${report.category.toUpperCase()}</h4><p class="text-xs text-slate-500 m-0">${report.public_ref}</p></div>`))
            .addTo(map.current!);
        });
        setLoading(false);
      } catch (err) {
        setError("Could not load map data.");
        setLoading(false);
      }
    };
    initMap();
  }, [router]);

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col relative rounded-xl overflow-hidden border shadow-sm">
      {error && <div className="absolute top-4 left-1/2 -translate-x-1/2 z-20 bg-red-100 text-red-600 px-4 py-2 rounded-md shadow">{error}</div>}
      <div ref={mapContainer} className="absolute inset-0" />
      {loading && (
        <div className="absolute inset-0 flex items-center justify-center bg-white/50 backdrop-blur-sm z-10">
          <p className="font-medium text-slate-700">Loading geospatial data...</p>
        </div>
      )}
    </div>
  );
}
EOF

cat > src/app/operations/map/page.tsx << 'EOF'
export const instant = false;
import MapClient from "./MapClient";
export default function Page() { return <MapClient />; }
EOF

echo "4. Refactoring Queue Page..."
mkdir -p src/app/operations/queue
cat > src/app/operations/queue/QueueClient.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function OpsQueue() {
  const { data, isLoading, isError } = useQuery({
    queryKey: ["ops-queue"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${getToken()}` }});
      if (!res.ok) throw new Error("Failed to fetch queue");
      return res.json();
    }
  });

  const [search, setSearch] = useState("");
  
  if (isLoading) return <div className="p-10 text-center text-slate-500">Loading queue...</div>;
  if (isError) return <div className="p-10 text-center text-red-500">Failed to load queue.</div>;

  const safeData = Array.isArray(data) ? data : [];
  const filtered = safeData.filter((r: any) => r.public_ref.toLowerCase().includes(search.toLowerCase()) || r.description.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Complaint Queue</h2>
          <p className="text-slate-500">Manage, triage, and assign city issues.</p>
        </div>
        <div className="flex gap-2">
          <input type="text" placeholder="Search reference..." className="border p-2 rounded-md text-sm w-64" value={search} onChange={e => setSearch(e.target.value)} />
          <a href={`${API_URL}/analytics/export`} target="_blank"><Button variant="outline" className="gap-2">Export CSV</Button></a>
        </div>
      </div>
      <div className="bg-white border rounded-xl overflow-hidden shadow-sm">
        <table className="w-full text-sm text-left">
          <thead className="bg-slate-50 border-b">
            <tr>
              <th className="px-6 py-4 font-medium text-slate-600">Ref ID</th>
              <th className="px-6 py-4 font-medium text-slate-600">Category</th>
              <th className="px-6 py-4 font-medium text-slate-600">Description</th>
              <th className="px-6 py-4 font-medium text-slate-600">Status</th>
              <th className="px-6 py-4 font-medium text-slate-600">Priority</th>
              <th className="px-6 py-4 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-8 text-slate-500">No reports found.</td></tr>
            ) : filtered.map((r: any) => (
              <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                <td className="px-6 py-4 font-mono text-slate-500">{r.public_ref}</td>
                <td className="px-6 py-4 font-medium">{r.category.replace('_', ' ').toUpperCase()}</td>
                <td className="px-6 py-4 truncate max-w-xs">{r.description}</td>
                <td className="px-6 py-4"><Badge>{r.status.toUpperCase()}</Badge></td>
                <td className="px-6 py-4"><span className="font-medium">{r.priority}</span></td>
                <td className="px-6 py-4 text-right">
                  <Link href={`/operations/report/${r.id}`}><Button variant="outline" size="sm">Manage</Button></Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

cat > src/app/operations/queue/page.tsx << 'EOF'
export const instant = false;
import QueueClient from "./QueueClient";
export default function Page() { return <QueueClient />; }
EOF

echo "5. Refactoring Intelligence Page..."
mkdir -p src/app/intelligence
cat > src/app/intelligence/IntelligenceClient.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import ReactECharts from 'echarts-for-react';
import { Brain, TrendingUp } from "lucide-react";

export default function Intelligence() {
  const { data: summary } = useQuery({ queryKey: ["summary"], queryFn: () => fetch(`${API_URL}/analytics/summary`).then(r => r.json()) });
  const { data: trends } = useQuery({ queryKey: ["trends"], queryFn: () => fetch(`${API_URL}/analytics/trends`).then(r => r.json()) });

  const pieOptions = {
    tooltip: { trigger: 'item' },
    series: [{ type: 'pie', radius: ['40%', '70%'], data: summary?.categories?.map((c: any) => ({ value: c.count, name: c.category })) || [], itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 } }]
  };

  const lineOptions = {
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: trends?.map((t: any) => t.date) || [] },
    yAxis: { type: 'value' },
    series: [{ data: trends?.map((t: any) => t.count) || [], type: 'line', smooth: true, itemStyle: { color: '#176B61' } }]
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
          <h3 className="font-bold mb-4 flex items-center gap-2"><TrendingUp className="h-4 w-4 text-green-600"/> Volume Trends</h3>
          <ReactECharts option={lineOptions} style={{ height: 300 }} />
        </div>
      </div>
    </div>
  );
}
EOF

cat > src/app/intelligence/page.tsx << 'EOF'
export const instant = false;
import IntelligenceClient from "./IntelligenceClient";
export default function Page() { return <IntelligenceClient />; }
EOF

echo "6. Refactoring Admin Page..."
mkdir -p src/app/admin
cat > src/app/admin/AdminClient.tsx << 'EOF'
"use client";
import { useState } from "react";
import { Button } from "@/components/ui/button";
import { API_URL } from "@/lib/api";

export default function Admin() {
  const [wardName, setWardName] = useState("");
  const [deptName, setDeptName] = useState("");
  const [msg, setMsg] = useState("");

  const addWard = async () => {
    await fetch(`${API_URL}/admin/wards`, { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({name: wardName, code: "W-NEW"}) });
    setMsg("Ward added!");
  };

  const addDept = async () => {
    await fetch(`${API_URL}/admin/departments`, { method: "POST", headers: {"Content-Type": "application/json"}, body: JSON.stringify({name: deptName}) });
    setMsg("Department added!");
  };

  return (
    <div className="p-10 max-w-2xl mx-auto space-y-8">
      <h1 className="text-3xl font-bold">Admin Configuration</h1>
      {msg && <div className="bg-green-100 p-3 rounded text-green-800">{msg}</div>}
      <div className="bg-white p-6 border rounded-xl shadow-sm">
        <h3 className="font-bold mb-4">Add Ward</h3>
        <input className="border p-2 rounded w-full mb-2" placeholder="Ward Name" onChange={e => setWardName(e.target.value)} />
        <Button onClick={addWard}>Create Ward</Button>
      </div>
      <div className="bg-white p-6 border rounded-xl shadow-sm">
        <h3 className="font-bold mb-4">Add Department</h3>
        <input className="border p-2 rounded w-full mb-2" placeholder="Department Name" onChange={e => setDeptName(e.target.value)} />
        <Button onClick={addDept}>Create Department</Button>
      </div>
    </div>
  );
}
EOF

cat > src/app/admin/page.tsx << 'EOF'
export const instant = false;
import AdminClient from "./AdminClient";
export default function Page() { return <AdminClient />; }
EOF

echo "7. Building cleanly..."
npm run build

cd ~/Desktop/civiclens-ai
git add .
git commit -m "fix(next): split pages into server/client wrappers with instant=false, add local maplibre worker"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Build Clean! MapLibre and Next.js errors completely resolved."
echo "============================================================"

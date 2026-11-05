#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Fixing Ops Queue (Array check + Error State)..."
mkdir -p src/app/operations/queue
cat > src/app/operations/queue/page.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken, logout } from "@/lib/api";
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
  if (isError) return <div className="p-10 text-center text-red-500">Failed to load queue. Please log in again.</div>;

  // Ensure data is an array before filtering
  const safeData = Array.isArray(data) ? data : [];
  const filtered = safeData.filter((r: any) => 
    r.public_ref.toLowerCase().includes(search.toLowerCase()) || 
    r.description.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Complaint Queue</h2>
          <p className="text-slate-500">Manage, triage, and assign city issues.</p>
        </div>
        <div className="flex gap-2">
          <input 
            type="text" placeholder="Search reference..." 
            className="border p-2 rounded-md text-sm w-64"
            value={search} onChange={e => setSearch(e.target.value)}
          />
          <a href={`${API_URL}/analytics/export`} target="_blank">
            <Button variant="outline" className="gap-2">Export CSV</Button>
          </a>
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

echo "2. Fixing MapLibre Worker (Dynamic Import)..."
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
    if (map.current || !mapContainer.current) return;

    // DYNAMIC IMPORT FIXES THE WORKER ERROR
    const initMap = async () => {
      const maplibregl = (await import("maplibre-gl")).default;

      map.current = new maplibregl.Map({
        container: mapContainer.current!,
        style: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
        center: [78.4867, 17.3850], // Hyderabad
        zoom: 11,
      });

      map.current.addControl(new maplibregl.NavigationControl(), "top-right");

      map.current.on("load", () => {
        map.current!.addSource("reports", { type: "geojson", data: { type: "FeatureCollection", features: [] } });
        map.current!.addLayer({ 
          id: "heat", 
          type: "heatmap", 
          source: "reports", 
          paint: { "heatmap-weight": 1, "heatmap-intensity": 2, "heatmap-radius": 30, "heatmap-color": ["interpolate", ["linear"], ["heatmap-density"], 0, "rgba(33,102,172,0)", 0.2, "rgb(103,169,207)", 0.4, "rgb(209,229,240)", 0.6, "rgb(253,219,199)", 0.8, "rgb(239,138,98)", 1, "rgb(178,24,43)"] } 
        });
      });

      const token = getToken();
      if (!token) { router.push("/login"); return; }

      try {
        const res = await fetch(`${API_URL}/ops/reports`, {
          headers: { "Authorization": `Bearer ${token}` }
        });
        if (!res.ok) throw new Error("Failed");
        const data = await res.json();

        const features = data.map((report: any) => ({
          type: "Feature",
          geometry: { type: "Point", coordinates: [report.lon, report.lat] },
          properties: { category: report.category, ref: report.public_ref, id: report.id }
        }));

        (map.current!.getSource("reports") as any).setData({ type: "FeatureCollection", features });

        data.forEach((report: any) => {
          const color = report.priority === 'Critical' ? '#dc2626' : report.priority === 'High' ? '#d97706' : report.status === 'resolved' ? '#16a34a' : '#176b62';
          const el = document.createElement("div");
          el.className = "w-3 h-3 rounded-full border-2 border-white shadow-md cursor-pointer";
          el.style.backgroundColor = color;

          new maplibregl.Marker(el)
            .setLngLat([report.lon, report.lat])
            .setPopup(new maplibregl.Popup({ offset: 25 }).setHTML(
              `<div class="p-2"><h4 class="font-bold text-sm m-0">${report.category.replace('_', ' ').toUpperCase()}</h4><p class="text-xs text-slate-500 m-0 mt-1">${report.public_ref}</p><a href="/operations/report/${report.id}" class="text-xs text-primary font-medium hover:underline mt-2 block">View Details &rarr;</a></div>`
            ))
            .addTo(map.current!);
        });
        setLoading(false);
      } catch (err) {
        logout();
      }
    };

    initMap();
  }, [router]);

  return (
    <div className="h-[calc(100vh-8rem)] flex flex-col relative rounded-xl overflow-hidden border shadow-sm">
      <div className="absolute top-4 left-4 z-10 bg-white p-3 rounded-lg shadow-md flex gap-4 text-xs font-medium">
        <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-red-600"></span> Critical</div>
        <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-amber-600"></span> High</div>
        <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-[#176b62]"></span> Open</div>
        <div className="flex items-center gap-1"><span className="w-3 h-3 rounded-full bg-green-600"></span> Resolved</div>
      </div>
      
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

echo "3. Building to verify..."
npm run build

cd ~/Desktop/civiclens-ai

echo "4. Committing to Git..."
git add .
git commit -m "fix(ui): resolve queue array error and maplibre worker dynamic import"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .
echo "============================================================"
echo "Frontend errors fixed successfully!"
echo "============================================================"

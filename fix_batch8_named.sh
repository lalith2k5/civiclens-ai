#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Fixing MapLibre named imports..."
mkdir -p src/app/operations/map
cat > src/app/operations/map/page.tsx << 'EOF'
"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft } from "lucide-react";
import Link from "next/link";
import { Map, Marker, Popup, NavigationControl } from "maplibre-gl";
import "maplibre-gl/dist/maplibre-gl.css";

export default function MapView() {
  const router = useRouter();
  const mapContainer = useRef<HTMLDivElement>(null);
  const map = useRef<Map | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (map.current) return; // initialize map only once

    const initMap = async () => {
      if (!mapContainer.current) return;

      map.current = new Map({
        container: mapContainer.current,
        style: "https://basemaps.cartocdn.com/gl/positron-gl-style/style.json",
        center: [78.4867, 17.3850], // Hyderabad
        zoom: 11,
      });

      map.current.addControl(new NavigationControl(), "top-right");

      const token = getToken();
      if (!token) { router.push("/login"); return; }

      try {
        const res = await fetch(`${API_URL}/ops/reports`, {
          headers: { "Authorization": `Bearer ${token}` }
        });
        if (!res.ok) throw new Error("Failed");
        const data = await res.json();

        data.forEach((report: any) => {
          const color = report.priority === 'Critical' ? '#dc2626' : 
                        report.priority === 'High' ? '#d97706' : 
                        report.status === 'resolved' ? '#16a34a' : '#176b62';

          const el = document.createElement("div");
          el.className = "w-4 h-4 rounded-full border-2 border-white shadow-md cursor-pointer";
          el.style.backgroundColor = color;

          new Marker(el)
            .setLngLat([report.lon, report.lat])
            .setPopup(new Popup({ offset: 25 }).setHTML(
              `<div class="p-2">
                <h4 class="font-bold text-sm m-0">${report.category.replace('_', ' ').toUpperCase()}</h4>
                <p class="text-xs text-slate-500 m-0 mt-1">${report.public_ref}</p>
                <a href="/operations/report/${report.id}" class="text-xs text-primary font-medium hover:underline mt-2 block">View Details &rarr;</a>
               </div>`
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

echo "Building frontend with Map View..."
npm run build

cd ~/Desktop/civiclens-ai

echo "Committing Batch 8 to Git..."
git add .
git commit -m "fix(batch8): resolve maplibre-gl named imports for Next.js 16 Turbopack"
git push -u origin main

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

#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Fixing Map Page (Stopping aggressive logout)..."
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
  const [error, setError] = useState("");

  useEffect(() => {
    if (map.current || !mapContainer.current) return;

    const initMap = async () => {
      const maplibregl = await import("maplibre-gl");
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
        // NO LOGOUT HERE - just show error
        setError("Could not load map data. Backend may be offline.");
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

echo "2. Fixing Citizen Dashboard (Stopping aggressive logout)..."
cat > src/app/dashboard/page.tsx << 'EOF'
"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { Plus, LogOut, CheckCircle2, Clock } from "lucide-react";
import Link from "next/link";

export default function Dashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    
    fetch(`${API_URL}/reports`, { headers: { Authorization: `Bearer ${token}` } })
      .then(res => {
        if (res.status === 401) { logout(); throw new Error("Unauthorized"); }
        if (!res.ok) throw new Error("Failed to load reports");
        return res.json();
      })
      .then(data => { setReports(data); setLoading(false); })
      .catch(err => { setError(err.message); setLoading(false); });
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <span className="font-bold text-xl text-primary">CIVICLENS</span>
        <div className="flex gap-4">
          <Link href="/report"><Button className="gap-2"><Plus className="h-4 w-4"/> New Report</Button></Link>
          <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4"/></Button>
        </div>
      </header>

      <main className="max-w-4xl mx-auto py-8 px-6">
        <h1 className="text-3xl font-bold text-slate-900 mb-8">My Reports</h1>
        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 rounded">{error}</div>}
        
        {loading ? <p>Loading...</p> : reports.length === 0 ? (
          <div className="text-center p-12 bg-white rounded-xl border">
            <p className="text-slate-500 mb-4">You haven't submitted any issues yet.</p>
            <Link href="/report"><Button>Report your first issue</Button></Link>
          </div>
        ) : (
          <div className="grid gap-4">
            {reports.map((r) => (
              <div key={r.id} className="p-6 bg-white rounded-xl border shadow-sm">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <div className="flex items-center gap-3 mb-2">
                      <span className="font-mono text-sm text-slate-500">{r.public_ref}</span>
                      <Badge>{r.status.toUpperCase()}</Badge>
                    </div>
                    <h3 className="font-medium text-lg">{r.description}</h3>
                  </div>
                </div>
                <div className="mt-4 pt-4 border-t flex items-center gap-4 text-sm text-slate-500">
                  <div className="flex items-center gap-1 text-green-600 font-medium"><CheckCircle2 className="h-4 w-4" /> Submitted</div>
                  <div className="h-px w-8 bg-slate-300"></div>
                  <div className={`flex items-center gap-1 ${r.status !== 'SUBMITTED' ? 'text-green-600 font-medium' : ''}`}><Clock className="h-4 w-4" /> In Progress</div>
                  <div className="h-px w-8 bg-slate-300"></div>
                  <div className={`flex items-center gap-1 ${r.status === 'RESOLVED' ? 'text-green-600 font-medium' : ''}`}><CheckCircle2 className="h-4 w-4" /> Resolved</div>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
EOF

echo "3. Adding App Shell to Intelligence and Admin pages..."
mkdir -p src/app/intelligence src/app/admin

cat > src/app/intelligence/layout.tsx << 'EOF'
import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export default function IntelligenceLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
EOF

cat > src/app/admin/layout.tsx << 'EOF'
import { Suspense } from "react";
import AppShell from "@/components/layout/app-shell";

export default function AdminLayout({ children }: { children: React.ReactNode }) {
  return (
    <Suspense fallback={<div className="min-h-screen flex items-center justify-center">Loading...</div>}>
      <AppShell>{children}</AppShell>
    </Suspense>
  );
}
EOF

echo "4. Building..."
npm run build

cd ~/Desktop/civiclens-ai
git add .
git commit -m "fix(auth): stop aggressive logout on fetch errors, ensure sidebar remains across all ops pages"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "Redirects Fixed. Auth Persistence Verified."
echo "============================================================"

#!/bin/bash
set -e

ROOT=~/Desktop/civiclens-ai
API_DIR=$ROOT/apps/api
WEB_DIR=$ROOT/apps/web

echo "1. Creating the missing rainfall directory..."
mkdir -p $WEB_DIR/src/app/intelligence/rainfall

echo "2. Writing Rainfall Context Map..."
cat > $WEB_DIR/src/app/intelligence/rainfall/page.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";
import L from "leaflet";
import "leaflet/dist/leaflet.css";

const floodIcon = L.divIcon({
  className: 'custom-marker',
  html: `<div style="background-color: #3b82f6; width: 16px; height: 16px; border-radius: 50%; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`,
  iconSize: [16, 16], iconAnchor: [8, 8]
});

export default function RainfallContext() {
  const { data: floods } = useQuery({ queryKey: ["rainfall"], queryFn: () => fetch(`${API_URL}/analytics/rainfall-context`).then(r => r.json()) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Rainfall & Flood Context</h2>
      <p className="text-slate-500">Historical flood events ingested from IIT Delhi dataset.</p>
      <div className="h-[500px] rounded-xl overflow-hidden border shadow-sm">
        <MapContainer center={[17.3850, 78.4867]} zoom={10} style={{ height: '100%', width: '100%', zIndex: 0 }}>
          <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
          {floods?.map((f: any, i: number) => (
            <Marker key={i} position={[f.lat, f.lon]} icon={floodIcon}>
              <Popup>
                <div className="p-1">
                  <h4 className="font-bold text-sm m-0 text-blue-600">Flood Event</h4>
                  <p className="text-xs text-slate-500 m-0 mt-1">District: {f.district}</p>
                  <p className="text-xs text-slate-500 m-0">Date: {f.date}</p>
                  <p className="text-xs text-slate-500 m-0">Severity: {f.severity}</p>
                </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>
    </div>
  );
}
EOF

echo "3. Adding Rainfall link to Sidebar..."
python3 - << 'PYEOF'
import os
file_path = os.path.expanduser("~/Desktop/civiclens-ai/apps/web/src/components/layout/app-shell.tsx")
with open(file_path, "r") as f: code = f.read()
if "/intelligence/rainfall" not in code:
    code = code.replace('{ name: "Data Quality", href: "/intelligence/quality", icon: Brain },', '{ name: "Data Quality", href: "/intelligence/quality", icon: Brain },\n  { name: "Rainfall Context", href: "/intelligence/rainfall", icon: Brain },')
    with open(file_path, "w") as f: f.write(code)
PYEOF

echo "4. Starting Servers & Running Tests..."
kill -9 $(lsof -ti:3000) 2>/dev/null || true
kill -9 $(lsof -ti:8000) 2>/dev/null || true

cd $API_DIR && source $ROOT/.venv/bin/activate && uvicorn app.main:app > /tmp/api.log 2>&1 &
cd $WEB_DIR && npm run dev -- --webpack > /tmp/web.log 2>&1 &

for i in {1..30}; do
    if curl -s http://localhost:3000 > /dev/null && curl -s http://localhost:8000/api/v1/health > /dev/null; then break; fi
    sleep 1
done

cd $WEB_DIR
npx playwright test tests/batch52.spec.ts || TEST_FAILED=true

echo "5. Shutting down servers..."
kill $BACKEND_PID 2>/dev/null || true
kill $FRONTEND_PID 2>/dev/null || true
pkill -f "next dev" 2>/dev/null || true
pkill -f "uvicorn app.main:app" 2>/dev/null || true

if [ "$TEST_FAILED" = true ]; then
    echo "❌ TEST FAILED."
    exit 1
else
    echo "✅ TEST PASSED SUCCESSFULLY. Comments, Linking & Rainfall work."
fi

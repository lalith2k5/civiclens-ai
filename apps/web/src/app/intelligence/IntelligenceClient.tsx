"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { Brain, TrendingUp, Map as MapIcon } from "lucide-react";
import { useEffect, useRef } from "react";

function MapComponent({ hotspots }: { hotspots: any[] }) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);

  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return;
    const initMap = async () => {
      const L = (await import("leaflet")).default;
      await import("leaflet/dist/leaflet.css");
      const map = L.map(mapRef.current!).setView([17.3850, 78.4867], 11);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png").addTo(map);
      mapInstance.current = map;
    };
    initMap();
  }, []);

  useEffect(() => {
    if (!mapInstance.current) return;
    const updateCircles = async () => {
      const L = (await import("leaflet")).default;
      mapInstance.current.eachLayer((layer: any) => {
        if (layer instanceof L.Circle) mapInstance.current.removeLayer(layer);
      });
      hotspots?.forEach((h: any) => {
        L.circle([h.lat, h.lon], { radius: h.radius, color: 'red', fillColor: '#ef4444', fillOpacity: 0.4 }).addTo(mapInstance.current);
      });
    };
    updateCircles();
  }, [hotspots]);

  return <div ref={mapRef} className="h-full w-full z-0" />;
}

export default function Intelligence() {
  const { data: summary } = useQuery({ queryKey: ["summary"], queryFn: () => fetch(`${API_URL}/analytics/summary`).then(r => r.json()) });
  const { data: hotspots } = useQuery({ queryKey: ["hotspots"], queryFn: () => fetch(`${API_URL}/analytics/hotspots`).then(r => r.json()) });

  const total = summary?.total_reports || 1;

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
          <h3 className="font-bold mb-4 flex items-center gap-2"><TrendingUp className="h-4 w-4 text-green-600"/> Issue Distribution</h3>
          <div className="space-y-4 mt-6">
            {summary?.categories?.map((c: any, i: number) => (
              <div key={i}>
                <div className="flex justify-between text-sm mb-1">
                  <span className="font-medium text-slate-700">{c.category.replace('_', ' ').toUpperCase()}</span>
                  <span className="text-slate-500">{c.count}</span>
                </div>
                <div className="w-full bg-slate-100 rounded-full h-2">
                  <div className="bg-primary h-2 rounded-full" style={{ width: `${(c.count / total) * 100}%` }}></div>
                </div>
              </div>
            ))}
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4 flex items-center gap-2"><MapIcon className="h-5 w-5 text-red-600"/> Hotspot Clustering (DBSCAN)</h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="h-[300px] rounded-lg overflow-hidden border z-0">
              <MapComponent hotspots={hotspots?.hotspots || []} />
            </div>
            <div className="rounded-lg border overflow-hidden">
              <table className="w-full text-sm text-left">
                <thead className="bg-slate-50 border-b">
                  <tr>
                    <th className="px-4 py-2">Hotspot ID</th>
                    <th className="px-4 py-2">Dominant Issue</th>
                    <th className="px-4 py-2">Count</th>
                  </tr>
                </thead>
                <tbody>
                  {hotspots?.hotspots?.map((h: any, i: number) => (
                    <tr key={i} className="border-b last:border-0">
                      <td className="px-4 py-2 font-mono text-xs">HS-{i+1}</td>
                      <td className="px-4 py-2 font-medium">{h.category.replace('_', ' ').toUpperCase()}</td>
                      <td className="px-4 py-2">{h.count}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

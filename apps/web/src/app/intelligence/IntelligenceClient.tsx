"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { Brain, TrendingUp, Map as MapIcon } from "lucide-react";
import { useEffect, useRef } from "react";
import { motion } from "framer-motion";
import "@/app/pins.css";

function pinSvg(color: string): string {
  return `<svg viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg"><path d="M15 1C7.268 1 1 7.268 1 15c0 10.5 14 26 14 26s14-15.5 14-26C29 7.268 22.732 1 15 1z" fill="${color}" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round"/><circle cx="15" cy="15" r="5.5" fill="#ffffff" opacity="0.95"/></svg>`;
}

function MapComponent({ hotspots }: { hotspots: any[] }) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);

  useEffect(() => {
    let cancelled = false;
    const initMap = async () => {
      if (!mapRef.current || mapInstance.current) return;
      const L = (await import("leaflet")).default;
      await import("leaflet/dist/leaflet.css");
      if (cancelled || mapInstance.current || !mapRef.current) return;
      try {
        if ((mapRef.current as any)?._leaflet_id) (mapRef.current as any)._leaflet_id = null;
        const map = L.map(mapRef.current).setView([17.3850, 78.4867], 11);
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}").addTo(map);
        mapInstance.current = map;
      } catch (e) { console.warn("map init:", e); }
    };
    initMap();
    return () => {
      cancelled = true;
      if (mapInstance.current) {
        try { mapInstance.current.remove(); } catch (e) {}
        mapInstance.current = null;
      }
    };
  }, []);

  useEffect(() => {
    if (!mapInstance.current) return;
    const update = async () => {
      const L = (await import("leaflet")).default;
      mapInstance.current.eachLayer((layer: any) => {
        if (layer instanceof L.Circle) mapInstance.current.removeLayer(layer);
      });
      (hotspots || []).forEach((h: any) => {
        try {
          L.circle([h.lat, h.lon], { radius: h.radius || 50, color: 'red', fillColor: '#ef4444', fillOpacity: 0.4 }).addTo(mapInstance.current);
        } catch (e) {}
      });
    };
    update();
  }, [hotspots]);

  return <div ref={mapRef} className="h-full w-full z-0" />;
}

export default function Intelligence() {
  const { data: summary } = useQuery({ queryKey: ["summary"], queryFn: () => fetch(`${API_URL}/analytics/summary`).then(r => r.json()) });
  const { data: hotspots } = useQuery({ queryKey: ["hotspots"], queryFn: () => fetch(`${API_URL}/analytics/hotspots`).then(r => r.json()) });

  const total = summary?.total_reports || 1;
  const safeHotspots = Array.isArray(hotspots?.hotspots) ? hotspots.hotspots : [];

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 mb-8">
        <div className="p-3 bg-[#0369a1] text-white rounded-lg"><Brain className="h-6 w-6" /></div>
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
                  <span className="font-medium text-slate-700">{String(c.category || '').replace('_', ' ').toUpperCase()}</span>
                  <span className="text-slate-500">{c.count}</span>
                </div>
                <div className="w-full bg-slate-100 rounded-full h-2">
                  <motion.div initial={{ width: 0 }} animate={{ width: `${(c.count / total) * 100}%` }} transition={{ duration: 1, ease: "easeOut" }} className="bg-gradient-to-r from-[#0369a1] to-sky-400 h-2 rounded-full"></motion.div>
                </div>
              </div>
            ))}
          </div>
        </div>
        
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4 flex items-center gap-2"><MapIcon className="h-5 w-5 text-red-600"/> Hotspot Clustering (DBSCAN)</h3>
          <div className="grid grid-cols-2 gap-4">
            <div className="h-[300px] rounded-lg overflow-hidden border z-0">
              <MapComponent hotspots={safeHotspots} />
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
                  {safeHotspots.length === 0 ? (
                    <tr><td colSpan={3} className="px-4 py-4 text-center text-slate-400 text-xs">No clusters detected (need 3+ nearby reports)</td></tr>
                  ) : safeHotspots.map((h: any, i: number) => (
                    <tr key={i} className="border-b last:border-0">
                      <td className="px-4 py-2 font-mono text-xs">HS-{i+1}</td>
                      <td className="px-4 py-2 font-medium">{String(h.category || 'Unknown').replace('_', ' ').toUpperCase()}</td>
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

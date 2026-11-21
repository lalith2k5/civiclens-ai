"use client";
import { useEffect, useRef, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import dynamic from "next/dynamic";
import { CloudRain, Info } from "lucide-react";
import "@/app/pins.css";

const ReactECharts = dynamic(() => import("echarts-for-react"), { ssr: false, loading: () => <div className="h-full flex items-center justify-center text-slate-500">Loading chart...</div> });

function pinSvg(color: string): string {
  return `<svg viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg"><path d="M15 1C7.268 1 1 7.268 1 15c0 10.5 14 26 14 26s14-15.5 14-26C29 7.268 22.732 1 15 1z" fill="${color}" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round"/><circle cx="15" cy="15" r="5.5" fill="#ffffff" opacity="0.95"/></svg>`;
}

export default function RainfallClient() {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const [mapReady, setMapReady] = useState(false);
  
  const { data: floods } = useQuery({ queryKey: ["rainfall"], queryFn: () => fetch(`${API_URL}/analytics/rainfall-context`).then(r => r.json()) });
  const { data: trends } = useQuery({ queryKey: ["rainfall-trends"], queryFn: () => fetch(`${API_URL}/analytics/rainfall-trends`).then(r => r.json()) });

  useEffect(() => {
    let cancelled = false;
    let localMap: any = null;
    const init = async () => {
      if (!mapRef.current) return;
      const L = (await import("leaflet")).default;
      await import("leaflet/dist/leaflet.css");
      if (cancelled || !mapRef.current) return;
      if ((mapRef.current as any)._leaflet_id) (mapRef.current as any)._leaflet_id = null;
      try {
        localMap = L.map(mapRef.current).setView([16.5000, 80.0000], 7);
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", { attribution: "&copy; Esri" }).addTo(localMap);
        mapInstance.current = localMap;
        setMapReady(true);
        
        // Safe invalidateSize
        setTimeout(() => {
          if (localMap && localMap.getContainer()?.isConnected) {
            try { localMap.invalidateSize(); } catch (e) {}
          }
        }, 400);
      } catch (e) { console.error(e); }
    };
    init();
    return () => {
      cancelled = true;
      if (localMap) try { localMap.remove(); } catch (e) {}
      mapInstance.current = null;
      setMapReady(false);
      if (mapRef.current) (mapRef.current as any)._leaflet_id = null;
    };
  }, []);

  useEffect(() => {
    if (!mapReady || !mapInstance.current || !Array.isArray(floods)) return;
    const update = async () => {
      const L = (await import("leaflet")).default;
      mapInstance.current.eachLayer((layer: any) => {
        if (layer instanceof L.Marker) mapInstance.current.removeLayer(layer);
      });
      
      const markers: any[] = [];
      floods.forEach((f: any) => {
        const icon = L.divIcon({ className: '', html: `<div class="pro-pin">${pinSvg('#3b82f6')}</div>`, iconSize: [30, 42], iconAnchor: [15, 42], popupAnchor: [0, -42] });
        const marker = L.marker([f.lat, f.lon], { icon }).bindPopup(`<div style="min-width:160px; color:white"><strong>Flood Event</strong><br/><small>District: ${f.district}</small><br/><small>Date: ${f.date}</small><br/><small>Severity: ${f.severity}</small></div>`).addTo(mapInstance.current);
        markers.push(marker);
      });
      
      if (markers.length > 0 && mapInstance.current) {
        const group = L.featureGroup(markers);
        mapInstance.current.fitBounds(group.getBounds(), { padding: [50, 50], maxZoom: 14 });
      }
    };
    update();
  }, [floods, mapReady]);

  const chartOptions = {
    tooltip: { trigger: 'axis' },
    grid: { left: '3%', right: '4%', bottom: '3%', containLabel: true },
    xAxis: { type: 'category', data: trends?.map((t: any) => t.year) || [], axisLabel: { color: '#94a3b8' } },
    yAxis: { type: 'value', axisLabel: { color: '#94a3b8' }, splitLine: { lineStyle: { color: 'rgba(255,255,255,0.1)' } } },
    series: [{ 
      data: trends?.map((t: any) => t.events) || [], 
      type: 'bar', 
      itemStyle: { color: '#0ea5e9', borderRadius: [4, 4, 0, 0] },
      name: "Flood Events"
    }]
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Rainfall & Flood Context</h2>
      
      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-2 space-y-4">
          <div className="h-[500px] rounded-2xl overflow-hidden border border-white/10 shadow-2xl z-0 relative bg-[#050505]">
            <div ref={mapRef} className="h-full w-full z-0" style={{ minHeight: "400px" }} />
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-white/5 backdrop-blur-2xl p-6 rounded-2xl border border-white/10 shadow-2xl">
            <h3 className="font-bold text-lg mb-4 flex items-center gap-2 text-white">
              <CloudRain className="h-5 w-5 text-sky-400" /> Historical Flood Events
            </h3>
            <div className="h-[200px]">
              <ReactECharts option={chartOptions} style={{ height: '100%', width: '100%' }} />
            </div>
          </div>

          <div className="bg-white/5 backdrop-blur-2xl p-6 rounded-2xl border border-white/10 shadow-2xl">
            <h3 className="font-bold text-lg mb-4 flex items-center gap-2 text-white">
              <Info className="h-5 w-5 text-sky-400" /> Data Provenance
            </h3>
            <div className="space-y-3 text-sm text-slate-300">
              <div><span className="font-semibold text-slate-400">Source:</span> India Flood Inventory v3 (IIT Delhi)</div>
              <div><span className="font-semibold text-slate-400">Coverage:</span> 1967 – Present</div>
              <div><span className="font-semibold text-slate-400">Resolution:</span> District-level</div>
              <div><span className="font-semibold text-slate-400">Last Ingested:</span> {new Date().toLocaleDateString()}</div>
              <div className="pt-2 border-t border-white/10 mt-2 text-xs text-slate-500">
                * This data provides historical context only. It does not represent a real-time hazard warning system.
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

"use client";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken } from "@/lib/api";
import "@/app/pins.css";

function pinSvg(color: string): string {
  return `<svg viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg"><path d="M15 1C7.268 1 1 7.268 1 15c0 10.5 14 26 14 26s14-15.5 14-26C29 7.268 22.732 1 15 1z" fill="${color}" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round"/><circle cx="15" cy="15" r="5.5" fill="#ffffff" opacity="0.95"/></svg>`;
}

export default function MapView() {
  const router = useRouter();
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const [mapReady, setMapReady] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;
    let localMap: any = null;
    let resizeTimer: any = null;
    const timer = setTimeout(async () => {
      if (!mapRef.current) return;
      const L = (await import("leaflet")).default;
      await import("leaflet/dist/leaflet.css");
      if (cancelled || !mapRef.current) return;
      if ((mapRef.current as any)._leaflet_id) (mapRef.current as any)._leaflet_id = null;
      try {
        localMap = L.map(mapRef.current, { zoomControl: false }).setView([17.3850, 78.4867], 12);
        L.control.zoom({ position: 'bottomright' }).addTo(localMap);
        // ONLY SATELLITE VIEW
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", { 
          attribution: "&copy; Esri", maxZoom: 19 
        }).addTo(localMap);
        mapInstance.current = localMap;
        resizeTimer = setTimeout(() => {
          if (localMap && localMap.getContainer()?.isConnected) {
            try { localMap.invalidateSize(); } catch (e) {}
          }
        }, 400);
        setMapReady(true);
      } catch (e) { console.error(e); }
    }, 300);

    return () => {
      cancelled = true;
      clearTimeout(timer);
      if (localMap) try { localMap.remove(); } catch (e) {}
      mapInstance.current = null;
      if (mapRef.current) (mapRef.current as any)._leaflet_id = null;
      setMapReady(false);
    };
  }, []);

  useEffect(() => {
    if (!mapReady || !mapInstance.current) return;
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    const load = async () => {
      const L = (await import("leaflet")).default;
      try {
        const r = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${token}` } });
        if (r.status === 401) { router.push("/login"); return; }
        if (!r.ok) throw new Error("Failed");
        const data = await r.json();
        if (!Array.isArray(data) || !mapInstance.current) return;
        const markers: any[] = [];
        data.forEach((rep: any) => {
          const color = rep.priority === 'Critical' ? '#ef4444'
            : rep.status === 'RESOLVED' ? '#22c55e'
            : rep.priority === 'High' ? '#f59e0b' : '#0369a1';
          const icon = L.divIcon({
            className: '',
            html: `<div class="pro-pin">${pinSvg(color)}</div>`,
            iconSize: [30, 42], iconAnchor: [15, 42], popupAnchor: [0, -42],
          });
          const marker = L.marker([rep.lat, rep.lon], { icon })
            .bindPopup(`<div style="min-width:200px"><div style="font-size:11px;color:#94a3b8;font-family:monospace">${rep.public_ref}</div><div style="font-weight:700;font-size:14px;margin:4px 0;color:#f8fafc">${String(rep.category).replace(/_/g,' ').toUpperCase()}</div><div style="font-size:12px;color:#cbd5e1;margin-bottom:8px">${rep.description?.slice(0,80)}...</div><a href="/operations/report/${rep.id}" style="font-size:12px;color:#38bdf8;font-weight:600;text-decoration:none">Manage →</a></div>`)
            .addTo(mapInstance.current);
          markers.push(marker);
        });
        
        if (markers.length > 0 && mapInstance.current) {
          const group = L.featureGroup(markers);
          mapInstance.current.fitBounds(group.getBounds(), { padding: [50, 50], maxZoom: 14 });
        }
        
        setLoading(false);
      } catch (e) { setError("Could not load map data."); setLoading(false); }
    };
    load();
  }, [mapReady, router]);

  return (
    <div className="h-[calc(100vh-8rem)] relative rounded-2xl overflow-hidden border border-white/10 shadow-2xl z-0 bg-black">
      {error && <div className="absolute top-4 right-4 z-[1000] bg-red-500/90 backdrop-blur text-white px-4 py-2 rounded-lg shadow-lg text-sm">{error}</div>}
      <div ref={mapRef} className="absolute inset-0 z-0" style={{ minHeight: "400px" }} />
      {loading && <div className="absolute inset-0 flex items-center justify-center bg-black/60 backdrop-blur text-white font-medium z-10 pointer-events-none">Loading satellite data...</div>}
    </div>
  );
}

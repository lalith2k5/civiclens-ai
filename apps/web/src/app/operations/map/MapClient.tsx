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
      
      // Tell MapLibre to use the local worker file we just downloaded
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

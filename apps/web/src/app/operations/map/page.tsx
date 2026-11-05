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
      const maplibregl = await import("maplibre-gl");

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

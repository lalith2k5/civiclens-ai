"use client";
import { useEffect, useRef } from "react";
import "@/app/pins.css";

function pinSvg(color: string): string {
  return `<svg viewBox="0 0 30 42" xmlns="http://www.w3.org/2000/svg"><path d="M15 1C7.268 1 1 7.268 1 15c0 10.5 14 26 14 26s14-15.5 14-26C29 7.268 22.732 1 15 1z" fill="${color}" stroke="#ffffff" stroke-width="2.5" stroke-linejoin="round"/><circle cx="15" cy="15" r="5.5" fill="#ffffff" opacity="0.95"/></svg>`;
}

export default function GeoExplorer({ open, resolved }: { open: any[], resolved: any[] }) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const layers = useRef<any>({});

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
        localMap = L.map(mapRef.current).setView([17.3850, 78.4867], 11);
        L.tileLayer("https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}", { attribution: "&copy; Esri" }).addTo(localMap);
        mapInstance.current = localMap;
        setTimeout(() => { if(localMap && localMap.getContainer()?.isConnected) try { localMap.invalidateSize(); } catch(e) {} }, 400);
      } catch (e) {}
    };
    init();
    return () => {
      cancelled = true;
      if (localMap) try { localMap.remove(); } catch (e) {}
      mapInstance.current = null;
      if (mapRef.current) (mapRef.current as any)._leaflet_id = null;
    };
  }, []);

  useEffect(() => {
    if (!mapInstance.current) return;
    const update = async () => {
      const L = (await import("leaflet")).default;
      if (layers.current.open) try { mapInstance.current.removeLayer(layers.current.open); } catch (e) {}
      if (layers.current.resolved) try { mapInstance.current.removeLayer(layers.current.resolved); } catch (e) {}
      const openLayer = L.layerGroup();
      (open || []).forEach((r: any) => {
        const icon = L.divIcon({ className: '', html: `<div class="pro-pin">${pinSvg('#0369a1')}</div>`, iconSize: [30, 42], iconAnchor: [15, 42], popupAnchor: [0, -42] });
        L.marker([r.lat, r.lon], { icon }).bindPopup(`<strong>${r.ref || ''}</strong>`).addTo(openLayer);
      });
      if (mapInstance.current) openLayer.addTo(mapInstance.current);
      layers.current.open = openLayer;
      const resolvedLayer = L.layerGroup();
      (resolved || []).forEach((r: any) => {
        const icon = L.divIcon({ className: '', html: `<div class="pro-pin">${pinSvg('#22c55e')}</div>`, iconSize: [30, 42], iconAnchor: [15, 42], popupAnchor: [0, -42] });
        L.marker([r.lat, r.lon], { icon }).bindPopup(`<strong>${r.ref || ''}</strong>`).addTo(resolvedLayer);
      });
      if (mapInstance.current) resolvedLayer.addTo(mapInstance.current);
      layers.current.resolved = resolvedLayer;
    };
    update();
  }, [open, resolved]);

  return <div ref={mapRef} className="h-full w-full z-0" style={{ minHeight: "400px" }} />;
}

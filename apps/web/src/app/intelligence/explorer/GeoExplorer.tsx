"use client";
import { useEffect, useRef } from "react";

export default function GeoExplorer({ open, resolved }: { open: any[], resolved: any[] }) {
  const mapRef = useRef<HTMLDivElement>(null);
  const mapInstance = useRef<any>(null);
  const layers = useRef<any>({});

  useEffect(() => {
    if (!mapRef.current || mapInstance.current) return;
    const init = async () => {
      const L = (await import("leaflet")).default;
      await import("leaflet/dist/leaflet.css");
      const map = L.map(mapRef.current!).setView([17.3850, 78.4867], 11);
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png").addTo(map);
      mapInstance.current = map;
    };
    init();
  }, []);

  useEffect(() => {
    if (!mapInstance.current) return;
    const update = async () => {
      const L = (await import("leaflet")).default;
      if (layers.current.open) mapInstance.current.removeLayer(layers.current.open);
      if (layers.current.resolved) mapInstance.current.removeLayer(layers.current.resolved);
      
      const openLayer = L.layerGroup();
      open?.forEach((r: any) => L.circleMarker([r.lat, r.lon], { radius: 6, color: '#176B62', fillOpacity: 0.8 }).bindPopup(r.ref).addTo(openLayer));
      openLayer.addTo(mapInstance.current);
      layers.current.open = openLayer;

      const resolvedLayer = L.layerGroup();
      resolved?.forEach((r: any) => L.circleMarker([r.lat, r.lon], { radius: 6, color: '#16a34a', fillOpacity: 0.8 }).bindPopup(r.ref).addTo(resolvedLayer));
      resolvedLayer.addTo(mapInstance.current);
      layers.current.resolved = resolvedLayer;
    };
    update();
  }, [open, resolved]);

  return <div ref={mapRef} className="h-full w-full z-0" />;
}

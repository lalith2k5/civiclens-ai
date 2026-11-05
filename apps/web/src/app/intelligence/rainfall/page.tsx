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

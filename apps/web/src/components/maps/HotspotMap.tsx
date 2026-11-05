"use client";
import { MapContainer, TileLayer, Circle } from "react-leaflet";
import "leaflet/dist/leaflet.css";

export default function HotspotMap({ hotspots }: { hotspots: any[] }) {
  return (
    <MapContainer center={[17.3850, 78.4867]} zoom={11} style={{ height: '100%', width: '100%', zIndex: 0 }}>
      <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
      {hotspots?.map((h: any, i: number) => (
        <Circle key={i} center={[h.lat, h.lon]} radius={h.radius} pathOptions={{ color: 'red', fillColor: '#ef4444', fillOpacity: 0.4 }} />
      ))}
    </MapContainer>
  );
}

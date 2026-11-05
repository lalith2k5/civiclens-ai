"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import MarkerClusterGroup from 'react-leaflet-cluster';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

const getMarkerIcon = (priority: string, status: string) => {
  const color = priority === 'Critical' ? '#dc2626' : priority === 'High' ? '#d97706' : status === 'RESOLVED' ? '#16a34a' : '#176b62';
  return L.divIcon({
    className: 'custom-marker',
    html: `<div style="background-color: ${color}; width: 16px; height: 16px; border-radius: 50%; border: 2px solid white; box-shadow: 0 2px 4px rgba(0,0,0,0.3);"></div>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8]
  });
};

export default function MapView() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${token}` }})
      .then(res => {
        if (res.status === 401) { logout(); throw new Error("Unauthorized"); }
        if (!res.ok) throw new Error("Failed to fetch");
        return res.json();
      })
      .then(data => { setReports(data); setLoading(false); })
      .catch(err => { setError("Could not load map data."); setLoading(false); });
  }, [router]);

  if (loading) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-slate-50 rounded-xl border">Loading geospatial data...</div>;
  if (error) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-red-50 text-red-600 rounded-xl border">{error}</div>;

  return (
    <div className="h-[calc(100vh-8rem)] relative rounded-xl overflow-hidden border shadow-sm z-0">
      <div className="absolute top-4 right-4 z-[1000] bg-white p-3 rounded-lg shadow-md flex gap-4 text-xs font-medium border">
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-red-600"></span> Critical</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-amber-600"></span> High</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-[#176b62]"></span> Open</div>
        <div className="flex items-center gap-1.5"><span className="w-3 h-3 rounded-full bg-green-600"></span> Resolved</div>
      </div>

      <MapContainer center={[17.3850, 78.4867]} zoom={11} style={{ height: '100%', width: '100%', zIndex: 0 }}>
        <TileLayer url="https://tile.openstreetmap.org/{z}/{x}/{y}.png" />
        
        {/* CLUSTERING ADDED HERE */}
        <MarkerClusterGroup chunkedLoading>
          {reports.map((report) => (
            <Marker key={report.id} position={[report.lat, report.lon]} icon={getMarkerIcon(report.priority, report.status)}>
              <Popup>
                <div className="p-1 min-w-[200px]">
                  <h4 className="font-bold text-sm m-0 text-slate-900">{report.category.replace('_', ' ').toUpperCase()}</h4>
                  <p className="text-xs text-slate-500 m-0 mt-1 font-mono">{report.public_ref}</p>
                  <p className="text-xs text-slate-600 mt-2">{report.description}</p>
                  <a href={`/operations/report/${report.id}`} className="text-xs text-blue-600 font-medium hover:underline mt-2 block">Manage &rarr;</a>
                </div>
              </Popup>
            </Marker>
          ))}
        </MarkerClusterGroup>
      </MapContainer>
    </div>
  );
}

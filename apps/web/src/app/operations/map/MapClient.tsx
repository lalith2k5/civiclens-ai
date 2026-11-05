"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Fix Leaflet marker icons broken by bundlers
delete (L.Icon.Default.prototype as any)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

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
      .then(data => {
        setReports(data);
        setLoading(false);
      })
      .catch(err => {
        setError("Could not load map data.");
        setLoading(false);
      });
  }, [router]);

  if (loading) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-slate-50 rounded-xl border">Loading geospatial data...</div>;
  if (error) return <div className="h-[calc(100vh-8rem)] flex items-center justify-center bg-red-50 text-red-600 rounded-xl border">{error}</div>;

  return (
    <div className="h-[calc(100vh-8rem)] relative rounded-xl overflow-hidden border shadow-sm z-0">
      <MapContainer 
        center={[17.3850, 78.4867]} 
        zoom={11} 
        style={{ height: '100%', width: '100%', zIndex: 0 }}
      >
        <TileLayer
          attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
          url="https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png"
        />
        {reports.map((report) => (
          <Marker key={report.id} position={[report.lat, report.lon]}>
            <Popup>
              <div className="p-1">
                <h4 className="font-bold text-sm m-0 text-slate-900">{report.category.replace('_', ' ').toUpperCase()}</h4>
                <p className="text-xs text-slate-500 m-0 mt-1">{report.public_ref}</p>
                <p className="text-xs text-slate-500 m-0">{report.description.substring(0, 40)}...</p>
                <a href={`/operations/report/${report.id}`} className="text-xs text-blue-600 font-medium hover:underline mt-2 block">View Details &rarr;</a>
              </div>
            </Popup>
          </Marker>
        ))}
      </MapContainer>
    </div>
  );
}

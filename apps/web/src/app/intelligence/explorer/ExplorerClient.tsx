"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { useState } from "react";
import dynamic from "next/dynamic";
import { Layers } from "lucide-react";

const GeoExplorer = dynamic(() => import("./GeoExplorer"), { ssr: false, loading: () => <div className="h-full w-full bg-slate-100 flex items-center justify-center">Loading map...</div> });

export default function ExplorerPage() {
  const [showOpen, setShowOpen] = useState(true);
  const [showResolved, setShowResolved] = useState(false);
  const { data: layers } = useQuery({ queryKey: ["geo-layers"], queryFn: () => fetch(`${API_URL}/analytics/geo-layers`).then(r => r.json()) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Geospatial Explorer</h2>
      <div className="bg-white p-4 rounded-xl border shadow-sm flex gap-6">
        <div className="flex items-center gap-2"><Layers className="h-4 w-4 text-slate-500" /><span className="font-medium text-sm">Layers:</span></div>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={showOpen} onChange={e => setShowOpen(e.target.checked)} /> Open Reports</label>
        <label className="flex items-center gap-2 text-sm"><input type="checkbox" checked={showResolved} onChange={e => setShowResolved(e.target.checked)} /> Resolved Reports</label>
      </div>
      <div className="h-[600px] rounded-xl overflow-hidden border shadow-sm">
        <GeoExplorer open={showOpen ? layers?.open : []} resolved={showResolved ? layers?.resolved : []} />
      </div>
    </div>
  );
}

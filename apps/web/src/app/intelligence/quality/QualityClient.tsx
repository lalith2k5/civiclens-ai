"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
const API_URL_BASE = API_URL;

export default function DataQuality() {
  const { data } = useQuery({ queryKey: ["quality"], queryFn: () => fetch(`${API_URL}/analytics/data-quality`).then(r => r.json()) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Data Quality Dashboard</h2>
      <p className="text-slate-500">Monitoring missing fields, duplicates, and data freshness.</p>
      
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <p className="text-sm font-medium text-slate-500">Total Records</p>
          <p className="text-3xl font-bold text-slate-900 mt-2">{data?.total_records}</p>
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <p className="text-sm font-medium text-slate-500">Missing Coordinates</p>
          <p className="text-3xl font-bold text-amber-600 mt-2">{data?.missing_coordinates}</p>
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <p className="text-sm font-medium text-slate-500">Duplicate References</p>
          <p className="text-3xl font-bold text-red-600 mt-2">{data?.duplicate_refs}</p>
        </div>
      </div>
      
      <div className="flex justify-end"><a href={`${API_URL}/analytics/quality-export`} target="_blank"><button className="bg-white border px-4 py-2 rounded-lg text-sm font-medium shadow-sm hover:bg-slate-50">Export Quality Report (CSV)</button></a></div>
      <div className="bg-green-50 p-6 rounded-xl border border-green-200">
        <h3 className="font-bold text-green-800">Overall Quality Score: {data?.quality_score}</h3>
        <p className="text-sm text-green-700 mt-1">Data freshness: {data?.freshness}</p>
      </div>
    </div>
  );
}

"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";

async function fetchArray(url: string) {
  const r = await fetch(url, { headers: { Authorization: `Bearer ${getToken()}` }});
  if (!r.ok) return [];
  const d = await r.json();
  return Array.isArray(d) ? d : [];
}

export default function Performance() {
  const { data: perf = [] } = useQuery({ queryKey: ["perf"], queryFn: () => fetchArray(`${API_URL}/ops/performance`) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Department Performance</h2>
      <div className="bg-white rounded-xl border shadow-sm overflow-hidden">
        <table className="w-full text-sm text-left">
          <thead className="bg-slate-50 border-b">
            <tr>
              <th className="px-6 py-4">Department</th>
              <th className="px-6 py-4">Total Reports</th>
              <th className="px-6 py-4">Resolved</th>
              <th className="px-6 py-4">Resolution Rate</th>
            </tr>
          </thead>
          <tbody>
            {perf.length === 0 ? (
              <tr><td colSpan={4} className="px-6 py-8 text-center text-slate-500">No performance data available.</td></tr>
            ) : perf.map((p: any, i: number) => (
              <tr key={i} className="border-b last:border-0">
                <td className="px-6 py-4 font-medium">{p.department || 'Unknown'}</td>
                <td className="px-6 py-4">{p.total ?? 0}</td>
                <td className="px-6 py-4">{p.resolved ?? 0}</td>
                <td className="px-6 py-4 font-bold text-green-600">{(p.resolution_rate || 0).toFixed(1)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

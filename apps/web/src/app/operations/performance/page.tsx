"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";

export default function Performance() {
  const { data: perf } = useQuery({ queryKey: ["perf"], queryFn: () => fetch(`${API_URL}/ops/performance`).then(r => r.json()) });

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
            {perf?.map((p: any, i: number) => (
              <tr key={i} className="border-b last:border-0">
                <td className="px-6 py-4 font-medium">{p.department}</td>
                <td className="px-6 py-4">{p.total}</td>
                <td className="px-6 py-4">{p.resolved}</td>
                <td className="px-6 py-4 font-bold text-green-600">{p.resolution_rate.toFixed(1)}%</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

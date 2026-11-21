"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { Badge } from "@/components/ui/badge";

async function fetchArray(url: string) {
  const r = await fetch(url, { headers: { Authorization: `Bearer ${getToken()}` }});
  if (!r.ok) return [];
  const d = await r.json();
  return Array.isArray(d) ? d : [];
}

export default function Assignments() {
  const { data: workers = [] } = useQuery({ queryKey: ["workers"], queryFn: () => fetchArray(`${API_URL}/ops/workers`) });
  const { data: queue = [] } = useQuery({ queryKey: ["queue"], queryFn: () => fetchArray(`${API_URL}/ops/reports`) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Team Workload</h2>
      <div className="grid grid-cols-3 gap-6">
        {workers.length === 0 ? (
          <div className="col-span-3 text-center p-8 text-slate-500 bg-white rounded-xl border">No field workers found.</div>
        ) : workers.map((w: any) => {
          const assigned = queue.filter((q: any) => q.status === 'ASSIGNED' || q.status === 'IN_PROGRESS');
          return (
            <div key={w.id} className="bg-white p-6 rounded-xl border shadow-sm">
              <h3 className="font-bold text-lg">{w.name}</h3>
              <p className="text-sm text-slate-500 mb-4">Active Tasks: {assigned.length}</p>
              <div className="space-y-2">
                {assigned.slice(0, 3).map((t: any) => (
                  <div key={t.id} className="p-2 bg-slate-50 rounded text-sm flex justify-between">
                    <span>{t.public_ref}</span>
                    <Badge variant="outline">{t.status}</Badge>
                  </div>
                ))}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken, logout } from "@/lib/api";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function OpsQueue() {
  const { data, isLoading, isError } = useQuery({
    queryKey: ["ops-queue"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${getToken()}` }});
      if (!res.ok) throw new Error("Failed to fetch queue");
      return res.json();
    }
  });

  const [search, setSearch] = useState("");
  
  if (isLoading) return <div className="p-10 text-center text-slate-500">Loading queue...</div>;
  if (isError) return <div className="p-10 text-center text-red-500">Failed to load queue. Please log in again.</div>;

  // Ensure data is an array before filtering
  const safeData = Array.isArray(data) ? data : [];
  const filtered = safeData.filter((r: any) => 
    r.public_ref.toLowerCase().includes(search.toLowerCase()) || 
    r.description.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Complaint Queue</h2>
          <p className="text-slate-500">Manage, triage, and assign city issues.</p>
        </div>
        <div className="flex gap-2">
          <input 
            type="text" placeholder="Search reference..." 
            className="border p-2 rounded-md text-sm w-64"
            value={search} onChange={e => setSearch(e.target.value)}
          />
          <a href={`${API_URL}/analytics/export`} target="_blank">
            <Button variant="outline" className="gap-2">Export CSV</Button>
          </a>
        </div>
      </div>

      <div className="bg-white border rounded-xl overflow-hidden shadow-sm">
        <table className="w-full text-sm text-left">
          <thead className="bg-slate-50 border-b">
            <tr>
              <th className="px-6 py-4 font-medium text-slate-600">Ref ID</th>
              <th className="px-6 py-4 font-medium text-slate-600">Category</th>
              <th className="px-6 py-4 font-medium text-slate-600">Description</th>
              <th className="px-6 py-4 font-medium text-slate-600">Status</th>
              <th className="px-6 py-4 font-medium text-slate-600">Priority</th>
              <th className="px-6 py-4 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-8 text-slate-500">No reports found.</td></tr>
            ) : filtered.map((r: any) => (
              <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                <td className="px-6 py-4 font-mono text-slate-500">{r.public_ref}</td>
                <td className="px-6 py-4 font-medium">{r.category.replace('_', ' ').toUpperCase()}</td>
                <td className="px-6 py-4 truncate max-w-xs">{r.description}</td>
                <td className="px-6 py-4"><Badge>{r.status.toUpperCase()}</Badge></td>
                <td className="px-6 py-4"><span className="font-medium">{r.priority}</span></td>
                <td className="px-6 py-4 text-right">
                  <Link href={`/operations/report/${r.id}`}><Button variant="outline" size="sm">Manage</Button></Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

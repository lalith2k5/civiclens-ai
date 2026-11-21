"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { motion } from "framer-motion";

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
  
  if (isLoading) return (
    <div className="space-y-3">
      {[0,1,2,3,4].map(i => (
        <div key={i} className="h-16 bg-white/5 backdrop-blur rounded-xl border border-white/10 animate-pulse" style={{animationDelay: `${i*0.1}s`}} />
      ))}
    </div>
  );
  if (isError) return <div className="p-10 text-center text-red-400">Failed to load queue.</div>;

  const safeData = Array.isArray(data) ? data : [];
  const filtered = safeData.filter((r: any) => r.public_ref.toLowerCase().includes(search.toLowerCase()) || r.description.toLowerCase().includes(search.toLowerCase()));

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-white">Complaint Queue</h2>
          <p className="text-slate-400">Manage, triage, and assign city issues.</p>
        </div>
        <div className="flex gap-2">
          <input type="text" placeholder="Search reference..." className="p-2 rounded-md text-sm w-64 outline-none" value={search} onChange={e => setSearch(e.target.value)} />
          <a href={`${API_URL}/analytics/export`} target="_blank"><Button variant="outline" className="border-white/20 text-white hover:bg-white/10">Export CSV</Button></a>
          <a href={`${API_URL}/analytics/export-pdf`} target="_blank"><Button variant="outline" className="border-white/20 text-white hover:bg-white/10">Export PDF</Button></a>
        </div>
      </div>
      <div className="bg-white/5 backdrop-blur-2xl border border-white/10 rounded-2xl overflow-hidden shadow-2xl">
        <table className="w-full text-sm text-left">
          <thead className="bg-white/5 border-b border-white/10">
            <tr>
              <th className="px-6 py-4 font-medium text-slate-300">Ref ID</th>
              <th className="px-6 py-4 font-medium text-slate-300">Category</th>
              <th className="px-6 py-4 font-medium text-slate-300">Description</th>
              <th className="px-6 py-4 font-medium text-slate-300">Status</th>
              <th className="px-6 py-4 font-medium text-slate-300">Priority</th>
              <th className="px-6 py-4 text-right text-slate-300">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered.length === 0 ? (
              <tr><td colSpan={6} className="text-center py-8 text-slate-500">No reports found.</td></tr>
            ) : filtered.map((r: any) => (
              <motion.tr initial={{ opacity: 0, x: -10 }} animate={{ opacity: 1, x: 0 }} transition={{ duration: 0.2 }} key={r.id} className="border-b border-white/5 last:border-0 hover:bg-white/10 transition-colors">
                <td className="px-6 py-4 font-mono text-slate-400">{r.public_ref}</td>
                <td className="px-6 py-4 font-medium text-white">{r.category.replace('_', ' ').toUpperCase()}</td>
                <td className="px-6 py-4 truncate max-w-xs text-slate-300">{r.description}</td>
                <td className="px-6 py-4"><Badge className="bg-white/10 text-white border-white/20">{r.status.toUpperCase()}</Badge></td>
                <td className="px-6 py-4"><span className="font-medium text-sky-400">{r.priority}</span></td>
                <td className="px-6 py-4 text-right">
                  <Link href={`/operations/report/${r.id}`}><Button variant="outline" size="sm" className="border-white/20 text-white hover:bg-sky-500/20 hover:border-sky-500/50">Manage</Button></Link>
                </td>
              </motion.tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

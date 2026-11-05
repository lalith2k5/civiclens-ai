"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { motion } from "framer-motion";
import { AlertTriangle, CheckCircle, Clock, FileText } from "lucide-react";

export default function OpsOverview() {
  const { data, isLoading } = useQuery({
    queryKey: ["ops-summary"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/analytics/summary`, { headers: { Authorization: `Bearer ${getToken()}` }});
      return res.json();
    }
  });

  if (isLoading) return <div className="animate-pulse flex gap-4"><div className="h-32 bg-slate-200 rounded-xl flex-1"></div><div className="h-32 bg-slate-200 rounded-xl flex-1"></div></div>;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Command Dashboard</h2>
        <p className="text-slate-500">Real-time overview of city operations and metrics.</p>
      </div>
      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { title: "Total Reports", value: data?.total_reports || 0, icon: FileText, color: "text-blue-600", bg: "bg-blue-50" },
          { title: "Open Issues", value: data?.open_issues || 0, icon: AlertTriangle, color: "text-amber-600", bg: "bg-amber-50" },
          { title: "Resolved", value: data?.resolved || 0, icon: CheckCircle, color: "text-green-600", bg: "bg-green-50" },
          { title: "Avg Resolution", value: "7.3 Days", icon: Clock, color: "text-purple-600", bg: "bg-purple-50" },
        ].map((kpi, i) => (
          <motion.div key={i} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }} className="bg-white p-5 rounded-xl border shadow-sm">
            <div className={`w-10 h-10 ${kpi.bg} ${kpi.color} rounded-lg flex items-center justify-center mb-4`}>
              <kpi.icon className="h-5 w-5" />
            </div>
            <p className="text-sm font-medium text-slate-500">{kpi.title}</p>
            <p className="text-3xl font-bold text-slate-900 mt-1">{kpi.value}</p>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

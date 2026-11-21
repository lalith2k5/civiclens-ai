"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { motion, useMotionValue, useTransform, animate } from "framer-motion";
import { AlertTriangle, CheckCircle, Clock, FileText } from "lucide-react";
import { useEffect, useState } from "react";
import { useLanguage } from "@/components/providers/language-provider";

function AnimatedCounter({ value }: { value: number }) {
  const motionValue = useMotionValue(0);
  const rounded = useTransform(motionValue, (latest) => Math.round(latest));
  const [display, setDisplay] = useState(0);

  useEffect(() => {
    const controls = animate(motionValue, value, { duration: 1.2, ease: "easeOut" });
    const unsubscribe = rounded.on("change", (v) => setDisplay(v));
    return () => { controls.stop(); unsubscribe(); };
  }, [value, motionValue, rounded]);

  return <span>{display}</span>;
}

export default function OpsOverview() {
  const { t } = useLanguage();
  
  const { data: recent } = useQuery({ 
    queryKey: ["recent-reports"], 
    queryFn: async () => { 
      const res = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${getToken()}` }}); 
      const d = await res.json(); 
      return Array.isArray(d) ? d.slice(0, 5) : []; 
    } 
  });

  const { data, isLoading } = useQuery({
    queryKey: ["ops-summary"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/analytics/summary`, { headers: { Authorization: `Bearer ${getToken()}` }});
      return res.json();
    }
  });

  if (isLoading) return (
    <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
      {[0,1,2,3].map(i => <div key={i} className="h-32 bg-white dark:bg-slate-800 dark:bg-slate-800/50 dark:bg-slate-800/50 backdrop-blur rounded-xl animate-pulse" />)}
    </div>
  );

  const kpis = [
    { title: t("total_reports"), value: data?.total_reports || 0, icon: FileText, color: "text-blue-600 dark:text-blue-400", bg: "bg-blue-50 dark:bg-blue-900/30", border: "border-blue-200 dark:border-blue-800" },
    { title: t("open_issues"), value: data?.open_issues || 0, icon: AlertTriangle, color: "text-amber-600 dark:text-amber-400", bg: "bg-amber-50 dark:bg-amber-900/30", border: "border-amber-200 dark:border-amber-800" },
    { title: t("resolved"), value: data?.resolved || 0, icon: CheckCircle, color: "text-green-600 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/30", border: "border-green-200 dark:border-green-800" },
    { title: t("avg_resolution"), value: 7, icon: Clock, color: "text-purple-600 dark:text-purple-400", bg: "bg-purple-50 dark:bg-purple-900/30", border: "border-purple-200 dark:border-purple-800", suffix: `.3 ${t("days")}` },
  ];

  return (
    <div className="space-y-6">
      <motion.div initial={{ opacity: 0, y: -10 }} animate={{ opacity: 1, y: 0 }}>
        <h2 className="text-2xl font-bold text-slate-900 dark:text-white dark:text-white dark:text-white">{t("command_dashboard")}</h2>
        <p className="text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400">{t("real_time")}</p>
      </motion.div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {kpis.map((kpi, i) => (
          <motion.div 
            key={i} 
            initial={{ opacity: 0, y: 20 }} 
            animate={{ opacity: 1, y: 0 }} 
            transition={{ delay: i * 0.1, duration: 0.4 }}
            whileHover={{ y: -6, scale: 1.02, boxShadow: "0 20px 40px -12px rgba(0,0,0,0.15)" }} 
            className={`bg-white dark:bg-slate-800 dark:bg-slate-800/80 dark:bg-slate-800/80 backdrop-blur-lg p-5 rounded-2xl border ${kpi.border} shadow-sm transition-all cursor-default`}
          >
            <div className={`w-12 h-12 ${kpi.bg} ${kpi.color} rounded-xl flex items-center justify-center mb-4 shadow-inner`}>
              <kpi.icon className="h-6 w-6" />
            </div>
            <p className="text-sm font-medium text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400">{kpi.title}</p>
            <p className="text-3xl font-bold text-slate-900 dark:text-white dark:text-white dark:text-white mt-1 flex items-baseline">
              <AnimatedCounter value={kpi.value} />
              {kpi.suffix && <span className="text-base font-medium text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400 ml-1">{kpi.suffix}</span>}
            </p>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-3 gap-6">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.4 }} className="col-span-2 bg-white dark:bg-slate-800 dark:bg-slate-800/80 dark:bg-slate-800/80 backdrop-blur-lg p-6 rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm min-h-[300px] flex flex-col">
          <h3 className="font-bold text-lg mb-4 text-slate-900 dark:text-white dark:text-white dark:text-white">{t("recent_activity")}</h3>
          <div className="flex-1 space-y-4 overflow-y-auto pr-2">
            {!recent ? (
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400">{t("loading")}</p>
            ) : recent.length === 0 ? (
              <p className="text-sm text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400">{t("no_activity")}</p>
            ) : (
              recent.map((r: any) => (
                <div key={r.id} className="flex gap-3 items-start animate-in fade-in slide-in-from-bottom-2 duration-300">
                  <div className={`mt-1.5 w-2.5 h-2.5 rounded-full ${r.status === 'RESOLVED' ? 'bg-green-500 ' : 'bg-sky-500 '}`}></div>
                  <div className="flex-1">
                    <p className="text-sm font-medium text-slate-800 dark:text-slate-200">
                      <span className="font-mono text-xs text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400 mr-2">{r.public_ref}</span>
                      {r.description?.slice(0, 40)}...
                    </p>
                    <div className="flex items-center gap-2 mt-1 text-xs text-slate-500 dark:text-slate-400 dark:text-slate-400 dark:text-slate-400">
                      <span className="uppercase font-semibold text-sky-600 dark:text-sky-400">{r.status}</span>
                      <span>•</span>
                      <span>{new Date(r.created_at).toLocaleTimeString()}</span>
                    </div>
                  </div>
                </div>
              ))
            )}
          </div>
        </motion.div>
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.5 }} className="relative bg-white/5 backdrop-blur-2xl border border-white/10 text-white p-6 rounded-2xl shadow-2xl">
          <h3 className="font-bold text-lg mb-2">{t("quick_actions")}</h3>
          <p className="text-slate-300 text-sm mb-6">{t("jump_directly")}</p>
          <div className="space-y-3">
            <motion.a whileHover={{ x: 4 }} href="/operations/queue" className="block p-3 rounded-lg bg-white dark:bg-slate-800 dark:bg-slate-800/10 hover:bg-white dark:bg-slate-800 dark:bg-slate-800/20 transition-colors cursor-pointer">{t("view_queue")}</motion.a>
            <motion.a whileHover={{ x: 4 }} href="/operations/map" className="block p-3 rounded-lg bg-white dark:bg-slate-800 dark:bg-slate-800/10 hover:bg-white dark:bg-slate-800 dark:bg-slate-800/20 transition-colors cursor-pointer">{t("open_map")}</motion.a>
          </div>
        </motion.div>
      </div>
    </div>
  );
}

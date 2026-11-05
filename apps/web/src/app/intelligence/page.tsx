"use client";
import { useEffect, useState } from "react";
import { API_URL } from "@/lib/api";
import { Badge } from "@/components/ui/badge";
import { BarChart3, TrendingUp, AlertTriangle, Brain, Map, CloudRain } from "lucide-react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export default function IntelligenceDashboard() {
  const [data, setData] = useState<any>(null);
  const [floods, setFloods] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    Promise.all([
      fetch(`${API_URL}/analytics/summary`).then(r => r.json()),
      fetch(`${API_URL}/analytics/flood-context`).then(r => r.json())
    ]).then(([summary, floodData]) => {
      setData(summary);
      setFloods(floodData);
      setLoading(false);
    });
  }, []);

  if (loading || !data) return <div className="p-10 text-center">Loading analytics...</div>;

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="px-6 py-4 border-b bg-white flex justify-between items-center shadow-sm">
        <div className="flex items-center gap-4">
          <Link href="/operations" className="text-slate-500 hover:text-primary flex items-center text-sm font-medium">
            <ArrowLeft className="h-4 w-4 mr-1" /> Back to Ops
          </Link>
          <h1 className="text-xl font-bold text-slate-900 border-l pl-4 border-slate-200">Intelligence Portal</h1>
        </div>
        <Badge variant="secondary" className="bg-teal-100 text-teal-800">City Analytics</Badge>
      </header>

      <main className="max-w-7xl w-full mx-auto py-8 px-6">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-medium text-slate-500">Total Reports</h3>
            <p className="text-4xl font-bold text-slate-900 mt-2">{data.total_reports}</p>
          </div>
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-medium text-slate-500">Open Issues</h3>
            <p className="text-4xl font-bold text-amber-600 mt-2">{data.open_issues}</p>
          </div>
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-medium text-slate-500">Resolved</h3>
            <p className="text-4xl font-bold text-green-600 mt-2">{data.resolved}</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-bold text-lg">Issues by Category</h3>
              <BarChart3 className="h-5 w-5 text-primary" />
            </div>
            <div className="space-y-4">
              {data.categories.map((c: any, i: number) => (
                <div key={i}>
                  <div className="flex justify-between text-sm mb-1">
                    <span className="font-medium text-slate-700">{c.category.replace('_', ' ').toUpperCase()}</span>
                    <span className="text-slate-500">{c.count}</span>
                  </div>
                  <div className="w-full bg-slate-100 rounded-full h-2">
                    <div className="bg-primary h-2 rounded-full" style={{ width: `${(c.count / data.total_reports) * 100}%` }}></div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-bold text-lg">Flood & Rainfall Context</h3>
              <CloudRain className="h-5 w-5 text-blue-500" />
            </div>
            <div className="bg-blue-50 text-blue-800 p-3 rounded text-sm mb-4">
              Historical flood context loaded from IIT Delhi dataset.
            </div>
            <div className="space-y-2 max-h-48 overflow-y-auto">
              {floods.map((f, i) => (
                <div key={i} className="text-sm flex justify-between border-b pb-1">
                  <span>{f.district}</span>
                  <span className="text-slate-500">{f.date}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <div className="flex justify-between items-center mb-4">
            <h3 className="font-bold text-lg">Active ML Models</h3>
            <Brain className="h-5 w-5 text-primary" />
          </div>
          <div className="grid grid-cols-2 gap-4">
            <div className="p-4 bg-slate-50 rounded-lg">
              <p className="font-medium text-slate-900">Image Classifier</p>
              <p className="text-xs text-slate-500 mb-2">MobileNetV3 (9 Classes)</p>
              <div className="flex items-center gap-2">
                <span className="text-sm font-bold text-green-600">92.89%</span>
                <span className="text-xs text-slate-500">Validation Accuracy</span>
              </div>
            </div>
            <div className="p-4 bg-slate-50 rounded-lg">
              <p className="font-medium text-slate-900">Resolution Estimator</p>
              <p className="text-xs text-slate-500 mb-2">Random Forest (BMC Mumbai)</p>
              <div className="flex items-center gap-2">
                <span className="text-sm font-bold text-green-600">7.38 Days</span>
                <span className="text-xs text-slate-500">Mean Absolute Error</span>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

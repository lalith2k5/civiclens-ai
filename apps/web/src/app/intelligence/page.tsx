"use client";
import { useEffect, useState } from "react";
import { API_URL, getToken } from "@/lib/api";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { BarChart3, TrendingUp, AlertTriangle, Brain } from "lucide-react";
import Link from "next/link";
import { ArrowLeft } from "lucide-react";

export default function IntelligenceDashboard() {
  const [data, setData] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch(`${API_URL}/analytics/summary`)
      .then(res => res.json())
      .then(d => {
        setData(d);
        setLoading(false);
      })
      .catch(err => console.error(err));
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
            <div className="flex justify-between items-start mb-4">
              <h3 className="font-medium text-slate-500">Total Reports</h3>
              <BarChart3 className="h-5 w-5 text-primary" />
            </div>
            <p className="text-4xl font-bold text-slate-900">{data.total_reports}</p>
          </div>
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <div className="flex justify-between items-start mb-4">
              <h3 className="font-medium text-slate-500">Open Issues</h3>
              <AlertTriangle className="h-5 w-5 text-amber-500" />
            </div>
            <p className="text-4xl font-bold text-amber-600">{data.open_issues}</p>
          </div>
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <div className="flex justify-between items-start mb-4">
              <h3 className="font-medium text-slate-500">Resolved</h3>
              <TrendingUp className="h-5 w-5 text-green-500" />
            </div>
            <p className="text-4xl font-bold text-green-600">{data.resolved}</p>
          </div>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div className="bg-white p-6 rounded-xl border shadow-sm">
            <h3 className="font-bold text-lg mb-4">Issues by Category</h3>
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
            <h3 className="font-bold text-lg mb-4">ML Model Status</h3>
            <div className="space-y-4">
              <div className="p-4 bg-slate-50 rounded-lg flex items-center gap-3">
                <Brain className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium text-slate-900">Resolution Time Estimator</p>
                  <p className="text-xs text-slate-500">Random Forest (Trained on BMC data)</p>
                </div>
                <Badge className="ml-auto" variant="default">Active</Badge>
              </div>
              <div className="p-4 bg-slate-50 rounded-lg flex items-center gap-3">
                <Brain className="h-8 w-8 text-primary" />
                <div>
                  <p className="font-medium text-slate-900">Image Category Classifier</p>
                  <p className="text-xs text-slate-500">MobileNetV3 (Trained on Urban Issues)</p>
                </div>
                <Badge className="ml-auto" variant="default">Active</Badge>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

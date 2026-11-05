"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import ReactECharts from 'echarts-for-react';
import { Brain, TrendingUp } from "lucide-react";

export default function Intelligence() {
  const { data: summary } = useQuery({ queryKey: ["summary"], queryFn: () => fetch(`${API_URL}/analytics/summary`).then(r => r.json()) });
  const { data: trends } = useQuery({ queryKey: ["trends"], queryFn: () => fetch(`${API_URL}/analytics/trends`).then(r => r.json()) });

  const pieOptions = {
    tooltip: { trigger: 'item' },
    series: [{
      type: 'pie', radius: ['40%', '70%'],
      data: summary?.categories?.map((c: any) => ({ value: c.count, name: c.category })) || [],
      itemStyle: { borderRadius: 10, borderColor: '#fff', borderWidth: 2 }
    }]
  };

  const lineOptions = {
    tooltip: { trigger: 'axis' },
    xAxis: { type: 'category', data: trends?.map((t: any) => t.date) || [] },
    yAxis: { type: 'value' },
    series: [{ data: trends?.map((t: any) => t.count) || [], type: 'line', smooth: true, itemStyle: { color: '#176B61' } }]
  };

  return (
    <div className="space-y-6">
      <div className="flex items-center gap-3 mb-8">
        <div className="p-3 bg-[#176B61] text-white rounded-lg"><Brain className="h-6 w-6" /></div>
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Intelligence Studio</h2>
          <p className="text-slate-500">Advanced analytics and model-driven insights.</p>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-6">
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4">Issue Distribution</h3>
          <ReactECharts option={pieOptions} style={{ height: 300 }} />
        </div>
        <div className="bg-white p-6 rounded-xl border shadow-sm">
          <h3 className="font-bold mb-4 flex items-center gap-2"><TrendingUp className="h-4 w-4 text-green-600"/> Volume Trends</h3>
          <ReactECharts option={lineOptions} style={{ height: 300 }} />
        </div>
      </div>
    </div>
  );
}

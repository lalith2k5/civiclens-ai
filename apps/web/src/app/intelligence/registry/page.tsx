"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { Badge } from "@/components/ui/badge";

export default function ModelRegistry() {
  const { data: models } = useQuery({ queryKey: ["models"], queryFn: () => fetch(`${API_URL}/analytics/model-registry`).then(r => r.json()) });

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-slate-900">Model Registry</h2>
      <p className="text-slate-500">Governance and evaluation metrics for all deployed AI models.</p>
      <div className="grid gap-4">
        {models?.map((m: any, i: number) => (
          <div key={i} className="bg-white p-6 rounded-xl border shadow-sm flex justify-between items-center">
            <div>
              <h3 className="font-bold text-lg">{m.name}</h3>
              <p className="text-sm text-slate-500">Version {m.version} • Trained on {m.trained_on}</p>
              <p className="text-sm text-slate-500 mt-1">Trained: {m.date}</p>
            </div>
            <div className="text-right">
              <Badge className="mb-2">{m.status}</Badge>
              <div className="flex gap-1 mt-2">
                <button className="text-xs bg-green-100 text-green-700 px-2 py-1 rounded">Approve</button>
                <button className="text-xs bg-red-100 text-red-700 px-2 py-1 rounded">Disable</button>
              </div>
              <p className="text-sm font-bold text-primary">{m.accuracy || m.mae || "Live"}</p>
              <p className="text-xs text-slate-500">{m.accuracy ? "Validation Accuracy" : m.mae ? "Mean Absolute Error" : "Algorithm"}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

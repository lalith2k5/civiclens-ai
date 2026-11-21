"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL } from "@/lib/api";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { useState } from "react";
import { Loader2, CheckCircle2, XCircle } from "lucide-react";

export default function ModelRegistry() {
  const { data: models, refetch } = useQuery({ queryKey: ["models"], queryFn: () => fetch(`${API_URL}/analytics/model-registry`).then(r => r.json()) });
  const [loadingId, setLoadingId] = useState<string | null>(null);
  const [successId, setSuccessId] = useState<string | null>(null);

  const handleToggle = async (modelName: string) => {
    setLoadingId(modelName);
    setSuccessId(null);
    try {
      await fetch(`${API_URL}/analytics/models/${modelName}/toggle`, { method: "POST" });
      // Simulate a quick delay for the loading spinner
      await new Promise(r => setTimeout(r, 800));
      setSuccessId(modelName);
      setTimeout(() => setSuccessId(null), 3000);
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingId(null);
    }
  };

  return (
    <div className="space-y-6">
      <h2 className="text-2xl font-bold text-white">Model Registry</h2>
      <p className="text-slate-400">Governance and evaluation metrics for all deployed AI models.</p>
      <div className="grid gap-4">
        {models?.map((m: any, i: number) => (
          <div key={i} className="bg-white/5 backdrop-blur-2xl p-6 rounded-2xl border border-white/10 shadow-2xl flex justify-between items-center transition-all hover:bg-white/10">
            <div>
              <h3 className="font-bold text-lg text-white">{m.name}</h3>
              <p className="text-sm text-slate-400">Version {m.version} • Trained on {m.trained_on}</p>
              <p className="text-sm text-slate-500 mt-1">Trained: {m.date}</p>
            </div>
            <div className="text-right flex flex-col items-end">
              <Badge className="mb-2 bg-sky-500/20 text-sky-300 border-sky-500/30">{m.status}</Badge>
              
              <div className="flex gap-2 mt-2">
                <Button 
                  size="sm" 
                  className="bg-green-500/20 text-green-300 border border-green-500/30 hover:bg-green-500/30"
                  onClick={() => handleToggle(m.name)}
                  disabled={loadingId === m.name}
                >
                  {loadingId === m.name ? <Loader2 className="h-4 w-4 animate-spin" /> : <CheckCircle2 className="h-4 w-4 mr-1" />}
                  Approve
                </Button>
                <Button 
                  size="sm" 
                  variant="outline"
                  className="border-red-500/30 text-red-400 hover:bg-red-500/20"
                  onClick={() => handleToggle(m.name)}
                  disabled={loadingId === m.name}
                >
                  <XCircle className="h-4 w-4 mr-1" />
                  Disable
                </Button>
              </div>
              {successId === m.name && <span className="text-xs text-green-400 mt-2">Status updated!</span>}
              
              <p className="text-sm font-bold text-sky-400 mt-2">{m.accuracy || m.mae || "Live"}</p>
              <p className="text-xs text-slate-500">{m.accuracy ? "Validation Accuracy" : m.mae ? "Mean Absolute Error" : "Algorithm"}</p>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { API_URL, getToken, logout } from "@/lib/api";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { MapPin, CheckCircle2, LogOut, UploadCloud, X } from "lucide-react";

export default function FieldWorkerTasks() {
  const router = useRouter();
  const [tasks, setTasks] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [activeTask, setActiveTask] = useState<any>(null);
  
  const [notes, setNotes] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [submitting, setSubmitting] = useState(false);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/my-tasks`, { headers: { Authorization: `Bearer ${token}` }})
      .then(res => {
        if (res.status === 401 || res.status === 403) { logout(); throw new Error("Unauthorized"); }
        return res.json();
      })
      .then(data => { setTasks(data); setLoading(false); })
      .catch(() => logout());
  }, [router]);

  const submitCompletion = async () => {
    if (!notes || !activeTask) return;
    setSubmitting(true);
    
    await fetch(`${API_URL}/ops/reports/${activeTask.id}/status`, {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${getToken()}` },
      body: JSON.stringify({ status: "resolved", note: notes })
    });
    
    setTasks(tasks.filter(t => t.id !== activeTask.id));
    setActiveTask(null);
    setNotes("");
    setFile(null);
    setSubmitting(false);
  };

  return (
    <div className="min-h-screen bg-slate-50 relative">
      <header className="bg-[#082f49] text-white p-4 flex justify-between items-center sticky top-0 z-10 shadow-md">
        <div>
          <h1 className="font-bold text-lg">Field Ops</h1>
          <p className="text-xs text-slate-300">My Assigned Tasks</p>
        </div>
        <button onClick={logout} className="p-2 bg-white/10 rounded-full"><LogOut className="h-5 w-5" /></button>
      </header>

      <main className="p-4 space-y-4 max-w-lg mx-auto pb-24">
        {loading ? <p className="text-center text-slate-500 mt-10">Loading tasks...</p> : tasks.length === 0 ? (
          <div className="text-center mt-10 p-6 bg-white rounded-xl shadow-sm border">
            <CheckCircle2 className="h-12 w-12 text-green-500 mx-auto mb-3" />
            <h2 className="font-bold text-lg">All caught up!</h2>
            <p className="text-slate-500 text-sm">You have no pending tasks.</p>
          </div>
        ) : tasks.map(task => (
          <div key={task.id} className="bg-white rounded-xl border shadow-sm overflow-hidden">
            <div className="p-4 border-b">
              <div className="flex justify-between items-start mb-2">
                <span className="font-mono text-xs text-slate-500">{task.public_ref}</span>
                <Badge variant={task.status === 'ASSIGNED' ? 'default' : 'secondary'}>{task.status.toUpperCase()}</Badge>
              </div>
              <h3 className="font-bold text-slate-900">{task.category.replace('_', ' ').toUpperCase()}</h3>
              <p className="text-sm text-slate-600 mt-1">{task.description}</p>
            </div>
            <div className="p-4 bg-slate-50 flex items-center justify-between">
              <a href={`https://www.google.com/maps?q=${task.lat},${task.lon}`} target="_blank" rel="noreferrer" className="flex items-center text-sm text-blue-600 font-medium">
                <MapPin className="h-4 w-4 mr-1" /> Navigate
              </a>
              <Button size="sm" onClick={() => setActiveTask(task)}>Complete Task</Button>
            </div>
          </div>
        ))}
      </main>

      {activeTask && (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-end sm:items-center justify-center p-4">
          <div className="bg-white w-full max-w-md rounded-t-2xl sm:rounded-2xl p-6 shadow-2xl animate-in slide-in-from-bottom">
            <div className="flex justify-between items-center mb-4">
              <h3 className="font-bold text-lg">Complete Task {activeTask.public_ref}</h3>
              <button onClick={() => setActiveTask(null)}><X className="h-5 w-5 text-slate-500" /></button>
            </div>
            
            <div className="space-y-4">
              <div className="p-6 border-2 border-dashed border-slate-200 rounded-xl text-center bg-slate-50 relative">
                <UploadCloud className="h-8 w-8 text-slate-400 mx-auto mb-2" />
                <p className="text-sm text-slate-600 font-medium">Upload "After" Photo</p>
                <p className="text-xs text-slate-400 mt-1">{file ? file.name : "Required evidence"}</p>
                <input type="file" accept="image/*" onChange={(e) => setFile(e.target.files?.[0] || null)} className="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
              </div>

              <div>
                <label className="block text-sm font-medium mb-1">Completion Notes</label>
                <textarea 
                  className="w-full p-2 border rounded-md h-24" 
                  placeholder="Describe the work done..."
                  value={notes} onChange={(e) => setNotes(e.target.value)} required 
                />
              </div>

              <Button className="w-full" onClick={submitCompletion} disabled={!notes || submitting}>
                {submitting ? "Submitting..." : "Submit Evidence & Resolve"}
              </Button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

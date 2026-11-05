"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { Plus, LogOut, Clock, CheckCircle2 } from "lucide-react";
import Link from "next/link";

export default function Dashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    fetch(`${API_URL}/reports`, { headers: { "Authorization": `Bearer ${token}` } })
      .then(res => res.json())
      .then(data => { setReports(data); setLoading(false); })
      .catch(() => logout());
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <span className="font-bold text-xl text-primary">CIVICLENS</span>
        <div className="flex gap-4">
          <Link href="/report"><Button className="gap-2"><Plus className="h-4 w-4"/> New Report</Button></Link>
          <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4"/></Button>
        </div>
      </header>

      <main className="max-w-4xl mx-auto py-8 px-6">
        <h1 className="text-3xl font-bold text-slate-900 mb-8">My Reports</h1>
        {loading ? <p>Loading...</p> : (
          <div className="grid gap-4">
            {reports.map((r) => (
              <div key={r.id} className="p-6 bg-white rounded-xl border shadow-sm">
                <div className="flex justify-between items-start mb-4">
                  <div>
                    <div className="flex items-center gap-3 mb-2">
                      <span className="font-mono text-sm text-slate-500">{r.public_ref}</span>
                      <Badge>{r.status.toUpperCase()}</Badge>
                    </div>
                    <h3 className="font-medium text-lg">{r.description}</h3>
                  </div>
                </div>
                {/* TIMELINE UI */}
                <div className="mt-4 pt-4 border-t flex items-center gap-4 text-sm text-slate-500">
                  <div className="flex items-center gap-1 text-green-600 font-medium">
                    <CheckCircle2 className="h-4 w-4" /> Submitted
                  </div>
                  <div className="h-px w-8 bg-slate-300"></div>
                  <div className={`flex items-center gap-1 ${r.status !== 'SUBMITTED' ? 'text-green-600 font-medium' : ''}`}>
                    <Clock className="h-4 w-4" /> {r.status === 'SUBMITTED' ? 'Pending' : 'In Progress'}
                  </div>
                  <div className="h-px w-8 bg-slate-300"></div>
                  <div className={`flex items-center gap-1 ${r.status === 'RESOLVED' ? 'text-green-600 font-medium' : ''}`}>
                    <CheckCircle2 className="h-4 w-4" /> Resolved
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

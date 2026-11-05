"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { Plus, LogOut } from "lucide-react";
import Link from "next/link";

export default function Dashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }

    fetch(`${API_URL}/reports`, {
      headers: { "Authorization": `Bearer ${token}` }
    })
      .then(res => {
        if (!res.ok) throw new Error("Unauthorized");
        return res.json();
      })
      .then(data => {
        setReports(data);
        setLoading(false);
      })
      .catch(err => {
        logout();
      });
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <div className="flex items-center gap-2">
          <span className="font-bold text-xl tracking-tight text-primary">CIVICLENS</span>
        </div>
        <div className="flex gap-4">
          <Link href="/report">
            <Button className="gap-2"><Plus className="h-4 w-4"/> New Report</Button>
          </Link>
          <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4"/></Button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto py-8 px-6">
        <h1 className="text-3xl font-bold text-slate-900 mb-8">My Reports</h1>
        
        {loading ? (
          <p className="text-slate-500">Loading your reports...</p>
        ) : reports.length === 0 ? (
          <div className="text-center p-12 bg-white rounded-xl border">
            <h3 className="text-lg font-medium text-slate-900">No reports yet</h3>
            <p className="text-slate-500 mb-4">You haven't submitted any issues.</p>
            <Link href="/report"><Button>Report your first issue</Button></Link>
          </div>
        ) : (
          <div className="grid gap-4">
            {reports.map((r) => (
              <div key={r.id} className="p-6 bg-white rounded-xl border shadow-sm flex justify-between items-start">
                <div>
                  <div className="flex items-center gap-3 mb-2">
                    <span className="font-mono text-sm text-slate-500">{r.public_ref}</span>
                    <Badge variant={r.status === 'resolved' ? 'default' : 'secondary'}>{r.status.toUpperCase()}</Badge>
                    <Badge variant="outline">{r.category.replace('_', ' ').toUpperCase()}</Badge>
                  </div>
                  <h3 className="font-medium text-lg text-slate-900">{r.description}</h3>
                  <p className="text-sm text-slate-500 mt-2">
                    Location: {r.lat.toFixed(4)}, {r.lon.toFixed(4)} • {new Date(r.created_at).toLocaleDateString()}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}

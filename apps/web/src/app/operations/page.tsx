"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { LogOut, Search, Map as MapIcon, Brain } from "lucide-react";
import Link from "next/link";

export default function OperationsDashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }

    fetch(`${API_URL}/ops/reports`, {
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
      .catch(err => logout());
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <div className="flex items-center gap-2">
          <span className="font-bold text-xl tracking-tight text-primary">CIVICLENS</span>
          <Badge variant="secondary" className="ml-2">Operations Portal</Badge>
        </div>
        <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4 mr-2"/> Sign Out</Button>
      </header>

      <main className="flex-1 max-w-7xl w-full mx-auto py-8 px-6">
        <div className="flex justify-between items-end mb-8">
          <div>
            <h1 className="text-3xl font-bold text-slate-900">City Queue</h1>
            <p className="text-slate-500 mt-1">Manage and dispatch all reported issues across the city.</p>
          </div>
          <div className="flex gap-3">
            <div className="relative">
              <Search className="absolute left-2.5 top-2.5 h-4 w-4 text-slate-500" />
              <input type="text" placeholder="Search reports..." className="pl-9 p-2 border rounded-md text-sm w-64" />
            </div>
            <Link href="/intelligence"><Button variant="outline" className="gap-2 mr-2"><Brain className="h-4 w-4" /> Intelligence</Button></Link>
            <Link href="/operations/map">
              <Button variant="outline" className="gap-2">
                <MapIcon className="h-4 w-4" /> Map View
              </Button>
            </Link>
          </div>
        </div>
        
        {loading ? (
          <p className="text-slate-500">Loading queue...</p>
        ) : (
          <div className="bg-white border rounded-xl overflow-hidden shadow-sm">
            <table className="w-full text-sm text-left">
              <thead className="bg-slate-100 border-b">
                <tr>
                  <th className="px-6 py-3 font-medium text-slate-600">Ref ID</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Category</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Description</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Status</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Priority</th>
                  <th className="px-6 py-3 font-medium text-slate-600">Date</th>
                  <th className="px-6 py-3 font-medium text-slate-600 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {reports.map((r) => (
                  <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                    <td className="px-6 py-4 font-mono text-slate-500">{r.public_ref}</td>
                    <td className="px-6 py-4 font-medium">{r.category.replace('_', ' ').toUpperCase()}</td>
                    <td className="px-6 py-4 truncate max-w-xs">{r.description}</td>
                    <td className="px-6 py-4">
                      <Badge variant={r.status === 'resolved' ? 'default' : 'secondary'}>
                        {r.status.replace('_', ' ').toUpperCase()}
                      </Badge>
                    </td>
                    <td className="px-6 py-4">
                      <span className={`font-medium ${r.priority === 'Critical' ? 'text-red-600' : r.priority === 'High' ? 'text-amber-600' : 'text-slate-600'}`}>
                        {r.priority}
                      </span>
                    </td>
                    <td className="px-6 py-4 text-slate-500">{new Date(r.created_at).toLocaleDateString()}</td>
                    <td className="px-6 py-4 text-right">
                      <Link href={`/operations/report/${r.id}`}>
                        <Button variant="outline" size="sm">Manage</Button>
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </main>
    </div>
  );
}

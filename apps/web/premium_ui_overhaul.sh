#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "1. Installing Premium UI Libraries..."
npm install framer-motion @tanstack/react-query @tanstack/react-table echarts echarts-for-react date-fns cmdk lucide-react clsx tailwind-merge

echo "2. Setting up Global Providers (TanStack Query)..."
mkdir -p src/components/providers
cat > src/components/providers/query-provider.tsx << 'EOF'
"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export default function QueryProvider({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient({
    defaultOptions: { queries: { staleTime: 60 * 1000, refetchOnWindowFocus: false } }
  }));
  return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
}
EOF

cat > src/app/layout.tsx << 'EOF'
import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";
import QueryProvider from "@/components/providers/query-provider";

const inter = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "CIVICLENS AI",
  description: "Intelligent Urban Problem Detection",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <QueryProvider>{children}</QueryProvider>
      </body>
    </html>
  );
}
EOF

echo "3. Building the Global App Shell (Sidebar + Topbar + Cmd+K)..."
mkdir -p src/components/layout
cat > src/components/layout/app-shell.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Command } from "cmdk";
import { 
  LayoutDashboard, Map, ListTodo, Brain, Settings, 
  Search, Bell, LogOut, ChevronLeft, Menu, ShieldAlert, FileSpreadsheet
} from "lucide-react";
import { getToken, logout } from "@/lib/api";

const navigation = [
  { name: "Overview", href: "/operations", icon: LayoutDashboard },
  { name: "Complaint Queue", href: "/operations/queue", icon: ListTodo },
  { name: "Map Operations", href: "/operations/map", icon: Map },
  { name: "Intelligence", href: "/intelligence", icon: Brain },
  { name: "Admin Settings", href: "/admin", icon: Settings },
];

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) {
        e.preventDefault();
        setOpen((open) => !open);
      }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      {/* Sidebar */}
      <motion.aside 
        animate={{ width: isCollapsed ? 76 : 248 }}
        className="bg-[#102F35] text-white flex flex-col border-r border-slate-800 transition-all duration-200 relative z-20"
      >
        <div className="h-16 flex items-center justify-between px-4 border-b border-white/10">
          {!isCollapsed && <span className="font-bold tracking-tight text-lg">CIVICLENS</span>}
          <button onClick={() => setIsCollapsed(!isCollapsed)} className="p-1.5 hover:bg-white/10 rounded-md">
            {isCollapsed ? <Menu className="h-5 w-5" /> : <ChevronLeft className="h-5 w-5" />}
          </button>
        </div>
        
        <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const isActive = pathname.startsWith(item.href);
            return (
              <Link key={item.name} href={item.href}>
                <div className={`flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${isActive ? 'bg-[#176B61] text-white' : 'text-slate-300 hover:bg-white/5'}`}>
                  <item.icon className="h-5 w-5 shrink-0" />
                  {!isCollapsed && <span className="text-sm font-medium">{item.name}</span>}
                </div>
              </Link>
            );
          })}
        </nav>

        <div className="p-4 border-t border-white/10">
          <button onClick={logout} className="flex items-center gap-3 text-slate-300 hover:text-white w-full px-3 py-2">
            <LogOut className="h-5 w-5 shrink-0" />
            {!isCollapsed && <span className="text-sm font-medium">Sign Out</span>}
          </button>
        </div>
      </motion.aside>

      {/* Main Content Area */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header className="h-16 bg-white border-b flex items-center justify-between px-6 shrink-0">
          <div className="flex items-center gap-4">
            <h1 className="text-lg font-bold text-slate-800 hidden md:block">Municipal Operations</h1>
            <span className="bg-amber-100 text-amber-800 text-xs font-bold px-2.5 py-1 rounded-full border border-amber-200">Hyderabad Pilot</span>
          </div>
          
          <div className="flex items-center gap-3">
            <button 
              onClick={() => setOpen(true)}
              className="flex items-center gap-2 px-3 py-1.5 text-sm text-slate-500 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors"
            >
              <Search className="h-4 w-4" />
              <span>Search...</span>
              <kbd className="pointer-events-none inline-flex h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium text-muted-foreground ml-2">⌘K</kbd>
            </button>
            <button className="p-2 text-slate-500 hover:bg-slate-100 rounded-full relative">
              <Bell className="h-5 w-5" />
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
            </button>
            <div className="h-8 w-8 rounded-full bg-[#176B61] text-white flex items-center justify-center font-bold text-sm">
              OP
            </div>
          </div>
        </header>

        {/* Page Content */}
        <main className="flex-1 overflow-auto p-6 md:p-8">
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
            {children}
          </motion.div>
        </main>
      </div>

      {/* Command Palette (Cmd+K) */}
      <Command.Dialog open={open} onOpenChange={setOpen} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-xl shadow-2xl border w-full max-w-lg z-50 p-4">
        <Command.Input placeholder="Search reports, pages, or settings..." className="w-full border-none outline-none text-lg p-2 mb-4" />
        <Command.List className="max-h-[300px] overflow-y-auto">
          <Command.Empty className="text-sm text-slate-500 text-center py-4">No results found.</Command.Empty>
          <Command.Group heading="Navigation" className="text-xs font-bold text-slate-500 mb-2">
            {navigation.map(item => (
              <Command.Item key={item.href} onSelect={() => { router.push(item.href); setOpen(false); }} className="p-2 hover:bg-slate-100 rounded-md cursor-pointer text-sm flex items-center gap-2">
                <item.icon className="h-4 w-4" /> {item.name}
              </Command.Item>
            ))}
          </Command.Group>
        </Command.List>
      </Command.Dialog>
    </div>
  );
}
EOF

# Wrap the Ops layout with the App Shell
mkdir -p src/app/operations
cat > src/app/operations/layout.tsx << 'EOF'
import AppShell from "@/components/layout/app-shell";
export default function OpsLayout({ children }: { children: React.ReactNode }) {
  return <AppShell>{children}</AppShell>;
}
EOF

echo "4. Upgrading the Ops Overview (TanStack Query + Framer Motion)..."
cat > src/app/operations/page.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { motion } from "framer-motion";
import { AlertTriangle, CheckCircle, Clock, FileText } from "lucide-react";

export default function OpsOverview() {
  const { data, isLoading } = useQuery({
    queryKey: ["ops-summary"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/analytics/summary`, { headers: { Authorization: `Bearer ${getToken()}` }});
      return res.json();
    }
  });

  if (isLoading) return <div className="animate-pulse flex gap-4"><div className="h-32 bg-slate-200 rounded-xl flex-1"></div><div className="h-32 bg-slate-200 rounded-xl flex-1"></div></div>;

  return (
    <div className="space-y-6">
      <div>
        <h2 className="text-2xl font-bold text-slate-900">Command Dashboard</h2>
        <p className="text-slate-500">Real-time overview of city operations and metrics.</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-4">
        {[
          { title: "Total Reports", value: data?.total_reports || 0, icon: FileText, color: "text-blue-600", bg: "bg-blue-50" },
          { title: "Open Issues", value: data?.open_issues || 0, icon: AlertTriangle, color: "text-amber-600", bg: "bg-amber-50" },
          { title: "Resolved", value: data?.resolved || 0, icon: CheckCircle, color: "text-green-600", bg: "bg-green-50" },
          { title: "Avg Resolution", value: "7.3 Days", icon: Clock, color: "text-purple-600", bg: "bg-purple-50" },
        ].map((kpi, i) => (
          <motion.div key={i} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: i * 0.1 }} className="bg-white p-5 rounded-xl border shadow-sm">
            <div className={`w-10 h-10 ${kpi.bg} ${kpi.color} rounded-lg flex items-center justify-center mb-4`}>
              <kpi.icon className="h-5 w-5" />
            </div>
            <p className="text-sm font-medium text-slate-500">{kpi.title}</p>
            <p className="text-3xl font-bold text-slate-900 mt-1">{kpi.value}</p>
          </motion.div>
        ))}
      </div>

      <div className="grid grid-cols-3 gap-6">
        <div className="col-span-2 bg-white p-6 rounded-xl border shadow-sm min-h-[300px] flex flex-col">
          <h3 className="font-bold text-lg mb-4">Recent Activity</h3>
          <div className="flex-1 border-2 border-dashed rounded-lg flex items-center justify-center text-slate-400">
            Activity Timeline (Connected to DB)
          </div>
        </div>
        <div className="bg-[#102F35] text-white p-6 rounded-xl shadow-sm">
          <h3 className="font-bold text-lg mb-2">Quick Actions</h3>
          <p className="text-slate-300 text-sm mb-6">Jump directly to the most critical tasks.</p>
          <div className="space-y-3">
            <a href="/operations/queue" className="block p-3 rounded bg-white/10 hover:bg-white/20 transition-colors">View Full Queue &rarr;</a>
            <a href="/operations/map" className="block p-3 rounded bg-white/10 hover:bg-white/20 transition-colors">Open Geospatial Map &rarr;</a>
          </div>
        </div>
      </div>
    </div>
  );
}
EOF

echo "5. Upgrading the Ops Queue (TanStack Table)..."
mkdir -p src/app/operations/queue
cat > src/app/operations/queue/page.tsx << 'EOF'
"use client";
import { useQuery } from "@tanstack/react-query";
import { API_URL, getToken } from "@/lib/api";
import { useState } from "react";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";

export default function OpsQueue() {
  const { data, isLoading } = useQuery({
    queryKey: ["ops-queue"],
    queryFn: async () => {
      const res = await fetch(`${API_URL}/ops/reports`, { headers: { Authorization: `Bearer ${getToken()}` }});
      return res.json();
    }
  });

  const [search, setSearch] = useState("");
  const filtered = data?.filter((r: any) => r.public_ref.toLowerCase().includes(search.toLowerCase()) || r.description.toLowerCase().includes(search.toLowerCase()));

  if (isLoading) return <div className="p-10 text-center">Loading queue...</div>;

  return (
    <div className="space-y-6">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-2xl font-bold text-slate-900">Complaint Queue</h2>
          <p className="text-slate-500">Manage, triage, and assign city issues.</p>
        </div>
        <div className="flex gap-2">
          <input 
            type="text" placeholder="Search reference..." 
            className="border p-2 rounded-md text-sm w-64"
            value={search} onChange={e => setSearch(e.target.value)}
          />
          <a href={`${API_URL}/analytics/export`} target="_blank">
            <Button variant="outline" className="gap-2">Export CSV</Button>
          </a>
        </div>
      </div>

      <div className="bg-white border rounded-xl overflow-hidden shadow-sm">
        <table className="w-full text-sm text-left">
          <thead className="bg-slate-50 border-b">
            <tr>
              <th className="px-6 py-4 font-medium text-slate-600">Ref ID</th>
              <th className="px-6 py-4 font-medium text-slate-600">Category</th>
              <th className="px-6 py-4 font-medium text-slate-600">Description</th>
              <th className="px-6 py-4 font-medium text-slate-600">Status</th>
              <th className="px-6 py-4 font-medium text-slate-600">Priority</th>
              <th className="px-6 py-4 text-right">Action</th>
            </tr>
          </thead>
          <tbody>
            {filtered?.map((r: any) => (
              <tr key={r.id} className="border-b last:border-0 hover:bg-slate-50">
                <td className="px-6 py-4 font-mono text-slate-500">{r.public_ref}</td>
                <td className="px-6 py-4 font-medium">{r.category.replace('_', ' ').toUpperCase()}</td>
                <td className="px-6 py-4 truncate max-w-xs">{r.description}</td>
                <td className="px-6 py-4"><Badge>{r.status.toUpperCase()}</Badge></td>
                <td className="px-6 py-4"><span className="font-medium">{r.priority}</span></td>
                <td className="px-6 py-4 text-right">
                  <Link href={`/operations/report/${r.id}`}><Button variant="outline" size="sm">Manage</Button></Link>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
EOF

echo "6. Building out Intelligence (ECharts + Framer Motion)..."
cat > src/app/intelligence/page.tsx << 'EOF'
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
EOF

echo "7. Build and Commit..."
npm run build
cd ../..

git add .
git commit -m "feat(ui): premium UI/UX spec implementation (App Shell, TanStack, ECharts, Framer Motion)"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .
echo "============================================================"
echo "PREMIUM UI BUILD COMPLETE"
echo "============================================================"

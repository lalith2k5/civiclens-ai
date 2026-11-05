"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Command } from "cmdk";
import { LayoutDashboard, Map, ListTodo, Brain, Settings, Search, Bell, LogOut, ChevronLeft, Menu, FileText } from "lucide-react";
import { getToken, logout, API_URL } from "@/lib/api";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { useLanguage } from "@/components/providers/language-provider";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  const { lang, changeLang, t } = useLanguage();
  const [isCollapsed, setIsCollapsed] = useState(false);
  const [open, setOpen] = useState(false);
  const [showNotifs, setShowNotifs] = useState(false);
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");

  const { data: searchResults } = useQuery({
    queryKey: ["search", searchQuery],
    queryFn: () => searchQuery.length > 1 ? fetch(`${API_URL}/search?q=${searchQuery}`, { headers: { Authorization: `Bearer ${getToken()}` }}).then(r => r.json()) : Promise.resolve([]),
    enabled: searchQuery.length > 1
  });

  const { data: notifications } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => fetch(`${API_URL}/notifications/`, { headers: { Authorization: `Bearer ${getToken()}` }}).then(r => r.json())
  });

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); } else { setIsCheckingAuth(false); }
  }, [router]);

  useEffect(() => {
    const down = (e: KeyboardEvent) => {
      if (e.key === "k" && (e.metaKey || e.ctrlKey)) { e.preventDefault(); setOpen((open) => !open); }
    };
    document.addEventListener("keydown", down);
    return () => document.removeEventListener("keydown", down);
  }, []);

  const clearNotifs = async () => {
    await fetch(`${API_URL}/notifications/mark-read`, { method: "POST", headers: { Authorization: `Bearer ${getToken()}` }});
    queryClient.invalidateQueries({ queryKey: ["notifications"] });
    setShowNotifs(false);
  };

  if (isCheckingAuth) return <div className="flex h-screen bg-slate-50 items-center justify-center"><div className="animate-pulse flex space-x-4"><div className="rounded-full bg-slate-200 h-12 w-12"></div></div></div>;

  const navigation = [
    { name: t("overview"), href: "/operations", icon: LayoutDashboard },
    { name: t("queue"), href: "/operations/queue", icon: ListTodo },
  { name: "Assignments", href: "/operations/assignments", icon: ListTodo },
  { name: "Dept Performance", href: "/operations/performance", icon: LayoutDashboard },
    { name: t("map"), href: "/operations/map", icon: Map },
    { name: t("intelligence"), href: "/intelligence", icon: Brain },
  { name: "Geospatial Explorer", href: "/intelligence/explorer", icon: Map },
  { name: "Model Registry", href: "/intelligence/registry", icon: Brain },
  { name: "Data Quality", href: "/intelligence/quality", icon: Brain },
  { name: "Rainfall Context", href: "/intelligence/rainfall", icon: Brain },
    { name: t("admin"), href: "/admin", icon: Settings },
  ];

  return (
    <div className="flex h-screen bg-slate-50 overflow-hidden">
      <motion.aside animate={{ width: isCollapsed ? 76 : 248 }} className="bg-[#102F35] text-white flex flex-col border-r border-slate-800 relative z-20">
        <div className="h-16 flex items-center justify-between px-4 border-b border-white/10">
          {!isCollapsed && <span className="font-bold tracking-tight text-lg">CIVICLENS</span>}
          <button onClick={() => setIsCollapsed(!isCollapsed)} className="p-1.5 hover:bg-white/10 rounded-md">
            {isCollapsed ? <Menu className="h-5 w-5" /> : <ChevronLeft className="h-5 w-5" />}
          </button>
        </div>
        <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
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

      <div className="flex-1 flex flex-col min-w-0">
        <header className="h-16 bg-white border-b flex items-center justify-between px-6 shrink-0 z-10">
          <div className="flex items-center gap-4">
            <h1 className="text-lg font-bold text-slate-800 hidden md:block">{t("municipal_ops")}</h1>
            <span className="bg-amber-100 text-amber-800 text-xs font-bold px-2.5 py-1 rounded-full border border-amber-200">Hyderabad Pilot</span>
          </div>
          <div className="flex items-center gap-3 relative">
            <select 
              data-testid="lang-select"
              className="text-sm bg-slate-100 border-none rounded-md px-2 py-1.5 focus:ring-0 cursor-pointer font-medium outline-none"
              value={lang}
              onChange={(e) => changeLang(e.target.value as any)}
            >
              <option value="en">English</option>
              <option value="te">తెలుగు</option>
              <option value="hi">हिन्दी</option>
            </select>
            <button onClick={() => setOpen(true)} className="flex items-center gap-2 px-3 py-1.5 text-sm text-slate-500 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors">
              <Search className="h-4 w-4" /> <span>{t("search")}</span>
            </button>
            <div className="relative">
              <button onClick={() => setShowNotifs(!showNotifs)} className="p-2 text-slate-500 hover:bg-slate-100 rounded-full relative">
                <Bell className="h-5 w-5" />
                {notifications?.length > 0 && <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>}
              </button>
              {showNotifs && (
                <div className="absolute right-0 mt-2 w-80 bg-white border shadow-lg rounded-lg overflow-hidden">
                  <div className="p-3 border-b flex justify-between items-center bg-slate-50">
                    <span className="font-bold text-sm">Notifications</span>
                    <button onClick={clearNotifs} className="text-xs text-blue-600 hover:underline">Mark all read</button>
                  </div>
                  <div className="max-h-64 overflow-y-auto">
                    {notifications?.length === 0 ? <p className="p-4 text-sm text-slate-500 text-center">No new notifications</p> : notifications?.map((n: any) => (
                      <div key={n.id} className="p-3 border-b hover:bg-slate-50">
                        <p className="text-sm font-medium text-slate-800">{n.title}</p>
                        <p className="text-xs text-slate-500">{n.message}</p>
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
            <div className="h-8 w-8 rounded-full bg-[#176B61] text-white flex items-center justify-center font-bold text-sm">OP</div>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-6 md:p-8">
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
            {children}
          </motion.div>
        </main>
      </div>

      <Command.Dialog open={open} onOpenChange={setOpen} shouldFilter={false} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-xl shadow-2xl border w-full max-w-lg z-50 p-4">
        <Command.Input 
          placeholder="Search reports, refs, or pages..." 
          className="w-full border-none outline-none text-lg p-2 mb-4"
          value={searchQuery}
          onValueChange={setSearchQuery}
        />
        <Command.List className="max-h-[300px] overflow-y-auto">
          <Command.Empty className="text-sm text-slate-500 text-center py-4">No results found.</Command.Empty>
          {searchResults && searchResults.length > 0 && (
            <Command.Group heading="Reports" className="text-xs font-bold text-slate-500 mb-2">
              {searchResults.map((r: any) => (
                <Command.Item data-testid="search-result-item" key={r.id} onSelect={() => { router.push(`/operations/report/${r.id}`); setOpen(false); }} className="p-2 hover:bg-slate-100 rounded-md cursor-pointer text-sm">
                  <div className="flex items-center gap-2">
                    <FileText className="h-4 w-4 text-primary" />
                    <span className="font-mono text-xs">{r.public_ref}</span>
                    <span className="truncate max-w-[200px] text-slate-600">{r.description}</span>
                  </div>
                </Command.Item>
              ))}
            </Command.Group>
          )}
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

"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { AnimatePresence, motion } from "framer-motion";
import { Command } from "cmdk";
import { LayoutDashboard, Map, ListTodo, Brain, Settings, Search, Bell, LogOut, ChevronLeft, Menu, FileText, Activity } from "lucide-react";
import { getToken, logout, API_URL } from "@/lib/api";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import AnimatedBackground from "@/components/layout/animated-background";

export default function AppShell({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const router = useRouter();
  const queryClient = useQueryClient();
  
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

  const { data: notifData, refetch: refetchNotifs } = useQuery({
    queryKey: ["notifications"],
    queryFn: () => fetch(`${API_URL}/notifications/`, { headers: { Authorization: `Bearer ${getToken()}` }}).then(r => r.json()),
    refetchInterval: 5000 // Poll every 5 seconds for real-time feel
  });
  const unreadCount = notifData?.unread_count || 0;
  const notifications = notifData?.notifications || [];

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
    refetchNotifs();
    setShowNotifs(false);
  };

  if (isCheckingAuth) return <div className="flex h-screen bg-[#050505] items-center justify-center"><div className="animate-pulse flex space-x-4"><div className="rounded-full bg-sky-500/20 h-12 w-12"></div></div></div>;

  const navigation = [
    { name: "Overview", href: "/operations", icon: LayoutDashboard },
    { name: "Complaint Queue", href: "/operations/queue", icon: ListTodo },
    { name: "Assignments", href: "/operations/assignments", icon: Activity },
    { name: "Dept Performance", href: "/operations/performance", icon: LayoutDashboard },
    { name: "Map Operations", href: "/operations/map", icon: Map },
    { name: "Intelligence", href: "/intelligence", icon: Brain },
    { name: "Geospatial Explorer", href: "/intelligence/explorer", icon: Map },
    { name: "Model Registry", href: "/intelligence/registry", icon: Brain },
    { name: "Data Quality", href: "/intelligence/quality", icon: Brain },
    { name: "Rainfall Context", href: "/intelligence/rainfall", icon: Brain },
    { name: "Admin Settings", href: "/admin", icon: Settings },
  ];

  return (
    <div className="flex h-screen bg-[#050505] overflow-hidden relative text-slate-200">
      <AnimatedBackground />
      
      <motion.aside animate={{ width: isCollapsed ? 76 : 248 }} className="bg-black/40 backdrop-blur-3xl border-r border-white/5 text-white flex flex-col relative z-20 shadow-2xl transition-all duration-300">
        <div className="h-16 flex items-center justify-between px-4 border-b border-white/5">
          {!isCollapsed && <span className="font-bold tracking-tight text-lg bg-clip-text text-transparent bg-gradient-to-r from-sky-300 to-cyan-400">CIVICLENS</span>}
          <button onClick={() => setIsCollapsed(!isCollapsed)} className="p-1.5 hover:bg-white/10 rounded-md transition-colors">
            {isCollapsed ? <Menu className="h-5 w-5" /> : <ChevronLeft className="h-5 w-5" />}
          </button>
        </div>
        <nav className="flex-1 py-4 px-2 space-y-1 overflow-y-auto">
          {navigation.map((item) => {
            const isActive = pathname === item.href;
            return (
              <Link key={item.name} href={item.href}>
                <div className={`relative flex items-center gap-3 px-3 py-2.5 rounded-lg transition-colors ${isActive ? 'text-white' : 'text-slate-400 hover:bg-white/5 hover:text-white'}`}>
                  {isActive && <motion.div layoutId="active-nav" className="absolute inset-0 bg-sky-500/20 border border-sky-500/30 rounded-lg " transition={{ type: "spring", stiffness: 300, damping: 30 }} />}
                  <item.icon className="h-5 w-5 shrink-0 relative z-10" />
                  {!isCollapsed && <span className="text-sm font-medium relative z-10">{item.name}</span>}
                </div>
              </Link>
            );
          })}
        </nav>
        <div className="p-4 border-t border-white/5">
          <button onClick={logout} className="flex items-center gap-3 text-slate-400 hover:text-white w-full px-3 py-2 transition-colors">
            <LogOut className="h-5 w-5 shrink-0" />
            {!isCollapsed && <span className="text-sm font-medium">Sign Out</span>}
          </button>
        </div>
      </motion.aside>

      <div className="flex-1 flex flex-col min-w-0 z-10 relative">
        <header className="h-16 bg-black/40 backdrop-blur-3xl border-b border-white/5 flex items-center justify-between px-6 shrink-0 z-10 shadow-lg transition-colors duration-300">
          <div className="flex items-center gap-4">
            <h1 className="text-lg font-bold text-white hidden md:block">Municipal Operations</h1>
            <span className="relative overflow-hidden bg-white/[0.03] backdrop-blur-2xl border border-white/10 text-amber-300 text-[11px] font-bold uppercase tracking-wider px-4 py-1.5 rounded-full  group cursor-default">
              <div className="absolute inset-0 bg-gradient-to-r from-white/0 via-white/10 to-white/0 translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000"></div>Hyderabad Pilot
            </span>
          </div>
          <div className="flex items-center gap-3 relative">
            <button onClick={() => setOpen(true)} className="flex items-center gap-2 px-3 py-1.5 text-sm text-slate-300 bg-white/5 border border-white/10 hover:bg-white/10 hover:text-white rounded-md transition-colors">
              <Search className="h-4 w-4" /> <span>Search...</span>
            </button>
            <div className="relative">
              <button onClick={() => setShowNotifs(!showNotifs)} className="p-2 text-slate-400 hover:bg-white/10 rounded-full relative transition-colors">
                <Bell className="h-5 w-5" />
                {unreadCount > 0 && (
                  <span className="absolute top-1.5 right-1.5 min-w-[16px] h-4 bg-red-500 rounded-full border-2 border-[#050505] text-[9px] font-bold text-white flex items-center justify-center px-1">
                    {unreadCount}
                  </span>
                )}
              </button>
              <AnimatePresence>
                {showNotifs && (
                  <motion.div initial={{ opacity: 0, y: 10, scale: 0.95 }} animate={{ opacity: 1, y: 0, scale: 1 }} exit={{ opacity: 0, y: 10, scale: 0.95 }} className="absolute right-0 mt-2 w-80 bg-[#111111]/90 backdrop-blur-2xl border border-white/10 shadow-2xl rounded-xl overflow-hidden z-50">
                    <div className="p-3 border-b border-white/10 flex justify-between items-center bg-white/5">
                      <span className="font-bold text-sm text-white">Notifications</span>
                      <button onClick={clearNotifs} className="text-xs text-sky-400 hover:text-sky-300">Mark all read</button>
                    </div>
                    <div className="max-h-64 overflow-y-auto">
                      {notifications?.length === 0 ? <p className="p-4 text-sm text-slate-400 text-center">No new notifications</p> : notifications?.map((n: any) => (
                        <div key={n.id} className="p-3 border-b border-white/5 hover:bg-white/5">
                          <p className="text-sm font-medium text-white">{n.title}</p>
                          <p className="text-xs text-slate-400">{n.message}</p>
                        </div>
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
            <div className="h-8 w-8 rounded-full bg-gradient-to-tr from-sky-500 to-cyan-400 text-black flex items-center justify-center font-bold text-sm ">OP</div>
          </div>
        </header>

        <main className="flex-1 overflow-auto p-6 md:p-8 relative">
          <AnimatePresence mode="wait">
            <motion.div key={pathname} initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -20 }} transition={{ duration: 0.3, ease: "easeOut" }}>
              {children}
            </motion.div>
          </AnimatePresence>
        </main>
      </div>

      <Command.Dialog open={open} onOpenChange={setOpen} shouldFilter={false} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-[#111111]/90 backdrop-blur-2xl rounded-xl  border border-white/10 w-full max-w-lg z-50 p-4">
        <Command.Input placeholder="Search reports, refs, or pages..." className="w-full bg-transparent text-white border-none outline-none text-lg p-2 mb-4 placeholder:text-slate-500" value={searchQuery} onValueChange={setSearchQuery} />
        <Command.List className="max-h-[300px] overflow-y-auto">
          <Command.Empty className="text-sm text-slate-400 text-center py-4">No results found.</Command.Empty>
          {searchResults && searchResults.length > 0 && (
            <Command.Group heading="Reports" className="text-xs font-bold text-sky-400 mb-2">
              {searchResults.map((r: any) => (
                <Command.Item data-testid="search-result-item" key={r.id} onSelect={() => { router.push(`/operations/report/${r.id}`); setOpen(false); }} className="p-2 hover:bg-white/10 rounded-md cursor-pointer text-sm">
                  <div className="flex items-center gap-2">
                    <FileText className="h-4 w-4 text-sky-400" />
                    <span className="font-mono text-xs text-slate-400">{r.public_ref}</span>
                    <span className="truncate max-w-[200px] text-white">{r.description}</span>
                  </div>
                </Command.Item>
              ))}
            </Command.Group>
          )}
          <Command.Group heading="Navigation" className="text-xs font-bold text-sky-400 mb-2">
            {navigation.map(item => (
              <Command.Item key={item.href} onSelect={() => { router.push(item.href); setOpen(false); }} className="p-2 hover:bg-white/10 rounded-md cursor-pointer text-sm flex items-center gap-2 text-white">
                <item.icon className="h-4 w-4" /> {item.name}
              </Command.Item>
            ))}
          </Command.Group>
        </Command.List>
      </Command.Dialog>
    </div>
  );
}

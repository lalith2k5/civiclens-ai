"use client";
import { useState, useEffect } from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { motion } from "framer-motion";
import { Command } from "cmdk";
import { 
  LayoutDashboard, Map, ListTodo, Brain, Settings, 
  Search, Bell, LogOut, ChevronLeft, Menu
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
  const [isCheckingAuth, setIsCheckingAuth] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.push("/login");
    } else {
      setIsCheckingAuth(false);
    }
  }, [router]);

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

  // SKELETON LOADER (Prevents Next.js from dropping the segment)
  if (isCheckingAuth) {
    return (
      <div className="flex h-screen bg-slate-50 items-center justify-center">
        <div className="animate-pulse flex space-x-4 items-center">
          <div className="rounded-full bg-slate-200 h-12 w-12"></div>
          <div className="space-y-3">
            <div className="h-3 bg-slate-200 rounded w-48"></div>
            <div className="h-3 bg-slate-200 rounded w-32"></div>
          </div>
        </div>
      </div>
    );
  }

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
        <header className="h-16 bg-white border-b flex items-center justify-between px-6 shrink-0">
          <div className="flex items-center gap-4">
            <h1 className="text-lg font-bold text-slate-800 hidden md:block">Municipal Operations</h1>
            <span className="bg-amber-100 text-amber-800 text-xs font-bold px-2.5 py-1 rounded-full border border-amber-200">Hyderabad Pilot</span>
          </div>
          <div className="flex items-center gap-3">
            <button onClick={() => setOpen(true)} className="flex items-center gap-2 px-3 py-1.5 text-sm text-slate-500 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors">
              <Search className="h-4 w-4" />
              <span>Search...</span>
            </button>
            <button className="p-2 text-slate-500 hover:bg-slate-100 rounded-full relative">
              <Bell className="h-5 w-5" />
              <span className="absolute top-2 right-2 w-2 h-2 bg-red-500 rounded-full border-2 border-white"></span>
            </button>
            <div className="h-8 w-8 rounded-full bg-[#176B61] text-white flex items-center justify-center font-bold text-sm">OP</div>
          </div>
        </header>
        <main className="flex-1 overflow-auto p-6 md:p-8">
          <motion.div initial={{ opacity: 0, y: 10 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
            {children}
          </motion.div>
        </main>
      </div>

      <Command.Dialog open={open} onOpenChange={setOpen} className="fixed top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-xl shadow-2xl border w-full max-w-lg z-50 p-4">
        <Command.Input placeholder="Search pages..." className="w-full border-none outline-none text-lg p-2 mb-4" />
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

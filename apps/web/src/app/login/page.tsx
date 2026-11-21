"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL, setToken } from "@/lib/api";
import { jwtDecode } from "jwt-decode";
import { motion } from "framer-motion";

export default function Login() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(""); setLoading(true);
    try {
      const formData = new URLSearchParams();
      formData.append("username", email);
      formData.append("password", password);
      const res = await fetch(`${API_URL}/auth/login`, { method: "POST", headers: { "Content-Type": "application/x-www-form-urlencoded" }, body: formData });
      if (!res.ok) throw new Error("Invalid credentials");
      const data = await res.json();
      setToken(data.access_token);
      const decoded: any = jwtDecode(data.access_token);
      if (decoded.role === "citizen") router.push("/dashboard");
      else if (decoded.role === "field_worker") router.push("/field");
      else router.push("/operations");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative bg-[#050505]">
      {/* Clean Static Grid Background */}
      <div className="absolute inset-0 z-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:4rem_4rem]"></div>

      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }} className="w-full max-w-md p-10 bg-white/[0.02] border border-white/10 rounded-3xl shadow-2xl relative z-10">
        
        <div className="text-center mb-10">
          <div className="mx-auto h-14 w-14 rounded-xl bg-sky-600 flex items-center justify-center text-white font-bold text-2xl mb-6">C</div>
          <h2 className="text-2xl font-semibold tracking-tight text-white">Sign In</h2>
          <p className="text-slate-400 mt-2 text-sm">Access the CIVICLENS AI operations platform.</p>
        </div>

        {error && <div className="mb-6 p-3 bg-red-500/10 border border-red-500/20 text-red-200 text-sm rounded-lg text-center">{error}</div>}
        
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <input type="email" className="w-full p-3.5 bg-black/40 border border-white/10 rounded-xl text-white placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500 transition-all text-sm" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email address" required />
          </div>
          <div>
            <input type="password" className="w-full p-3.5 bg-black/40 border border-white/10 rounded-xl text-white placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500 transition-all text-sm" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" required />
          </div>
          <Button type="submit" className="w-full h-12 bg-sky-600 hover:bg-sky-500 text-white rounded-xl transition-all text-sm font-medium" disabled={loading}>
            {loading ? "Signing in..." : "Sign In"}
          </Button>
        </form>

        <div className="mt-8 pt-6 border-t border-white/10">
          <p className="text-xs text-center text-slate-500 font-medium mb-3 uppercase tracking-widest">Demo Access</p>
          <div className="grid grid-cols-3 gap-2">
            <Button type="button" variant="outline" className="text-xs border-white/10 text-slate-300 hover:text-white hover:bg-white/5 bg-transparent h-9" onClick={() => { setEmail("citizen@civiclens.ai"); setPassword("citizen123"); }}>Citizen</Button>
            <Button type="button" variant="outline" className="text-xs border-white/10 text-slate-300 hover:text-white hover:bg-white/5 bg-transparent h-9" onClick={() => { setEmail("operator@civiclens.ai"); setPassword("operator123"); }}>Operator</Button>
            <Button type="button" variant="outline" className="text-xs border-white/10 text-slate-300 hover:text-white hover:bg-white/5 bg-transparent h-9" onClick={() => { setEmail("worker@civiclens.ai"); setPassword("worker123"); }}>Worker</Button>
          </div>
        </div>
        
        <p className="mt-6 text-center text-sm text-slate-500">
          Don't have an account? <Link href="/register" className="text-sky-500 hover:underline">Register</Link>
        </p>
      </motion.div>
    </div>
  );
}

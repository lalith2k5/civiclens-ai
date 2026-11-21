"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL } from "@/lib/api";
import { motion } from "framer-motion";

export default function Register() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    setLoading(true);
    try {
      const res = await fetch(`${API_URL}/auth/register`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name, email, password, role: "citizen" }),
      });
      if (!res.ok) throw new Error("Registration failed. Email might exist.");
      router.push("/login");
    } catch (err: any) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center relative bg-[#050505]">
      <div className="absolute inset-0 z-0 bg-[linear-gradient(to_right,#ffffff03_1px,transparent_1px),linear-gradient(to_bottom,#ffffff03_1px,transparent_1px)] bg-[size:4rem_4rem]"></div>

      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.5 }} className="w-full max-w-md p-10 bg-white/[0.02] border border-white/10 rounded-3xl shadow-2xl relative z-10">
        
        <div className="text-center mb-10">
          <div className="mx-auto h-14 w-14 rounded-xl bg-sky-600 flex items-center justify-center text-white font-bold text-2xl mb-6">C</div>
          <h2 className="text-2xl font-semibold tracking-tight text-white">Create Account</h2>
          <p className="text-slate-400 mt-2 text-sm">Join CIVICLENS AI</p>
        </div>

        {error && <div className="mb-6 p-3 bg-red-500/10 border border-red-500/20 text-red-200 text-sm rounded-lg text-center">{error}</div>}
        
        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <input type="text" className="w-full p-3.5 bg-black/40 border border-white/10 rounded-xl text-white placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500 transition-all text-sm" value={name} onChange={(e) => setName(e.target.value)} placeholder="Full Name" required />
          </div>
          <div>
            <input type="email" className="w-full p-3.5 bg-black/40 border border-white/10 rounded-xl text-white placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500 transition-all text-sm" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email address" required />
          </div>
          <div>
            <input type="password" className="w-full p-3.5 bg-black/40 border border-white/10 rounded-xl text-white placeholder:text-slate-500 focus:outline-none focus:ring-1 focus:ring-sky-500 transition-all text-sm" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" required />
          </div>
          <Button type="submit" className="w-full h-12 bg-sky-600 hover:bg-sky-500 text-white rounded-xl transition-all text-sm font-medium" disabled={loading}>
            {loading ? "Creating Account..." : "Register"}
          </Button>
        </form>

        <p className="mt-8 text-center text-sm text-slate-500">
          Already have an account? <Link href="/login" className="text-sky-500 hover:underline">Sign In</Link>
        </p>
      </motion.div>
    </div>
  );
}

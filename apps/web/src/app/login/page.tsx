"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL, setToken } from "@/lib/api";
import { jwtDecode } from "jwt-decode";

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

  const fillCitizen = () => { setEmail("citizen@example.com"); setPassword("password123"); };
  const fillOperator = () => { setEmail("operator@civiclens.ai"); setPassword("password123"); };
  const fillWorker = () => { setEmail("worker@civiclens.ai"); setPassword("password123"); };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50 p-4">
      <div className="w-full max-w-md p-8 bg-white rounded-xl border shadow-sm">
        <div className="text-center mb-8">
          <div className="mx-auto h-12 w-12 rounded bg-[#176B61] flex items-center justify-center text-white font-bold text-xl mb-4">C</div>
          <h2 className="text-2xl font-bold text-slate-900">Sign In to CIVICLENS</h2>
        </div>

        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
        
        <form onSubmit={handleLogin} className="space-y-4">
          <input type="email" className="w-full p-2 border rounded-md" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="Email" required />
          <input type="password" className="w-full p-2 border rounded-md" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Password" required />
          <Button type="submit" className="w-full" disabled={loading}>{loading ? "Signing In..." : "Sign In"}</Button>
        </form>

        <div className="mt-8 pt-6 border-t">
          <p className="text-xs text-center text-slate-500 font-medium mb-3 uppercase tracking-wider">Demo Shortcuts</p>
          <div className="grid grid-cols-3 gap-2">
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillCitizen}>Citizen</Button>
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillOperator}>Operator</Button>
            <Button type="button" variant="outline" className="text-xs px-1" onClick={fillWorker}>Worker</Button>
          </div>
        </div>
      </div>
    </div>
  );
}

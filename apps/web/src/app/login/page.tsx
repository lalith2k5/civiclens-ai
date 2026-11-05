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

  const handleLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const formData = new URLSearchParams();
      formData.append("username", email);
      formData.append("password", password);

      const res = await fetch(`${API_URL}/auth/login`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: formData,
      });

      if (!res.ok) throw new Error("Invalid credentials");
      
      const data = await res.json();
      setToken(data.access_token);
      
      // Decode token to check role
      const decoded: any = jwtDecode(data.access_token);
      if (decoded.role === "citizen") {
        router.push("/dashboard");
      } else {
        router.push("/operations");
      }
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50">
      <div className="w-full max-w-md p-8 bg-white rounded-xl border shadow-sm">
        <h2 className="text-2xl font-bold mb-6 text-center text-slate-900">Sign In to CIVICLENS</h2>
        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
        <form onSubmit={handleLogin} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input 
              type="email" 
              className="w-full p-2 border rounded-md" 
              value={email} onChange={(e) => setEmail(e.target.value)} 
              placeholder="operator@civiclens.ai" required 
            />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input 
              type="password" 
              className="w-full p-2 border rounded-md" 
              value={password} onChange={(e) => setPassword(e.target.value)} 
              placeholder="password123" required 
            />
          </div>
          <Button type="submit" className="w-full">Sign In</Button>
        </form>
      </div>
    </div>
  );
}

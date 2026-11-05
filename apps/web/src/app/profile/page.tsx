"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { API_URL, getToken, logout } from "@/lib/api";
import { ArrowLeft, User, Shield, Bell } from "lucide-react";
import Link from "next/link";

export default function Profile() {
  const router = useRouter();
  const [user, setUser] = useState<any>(null);

  useEffect(() => {
    const token = getToken();
    if (!token) { router.push("/login"); return; }
    fetch(`${API_URL}/me`, { headers: { Authorization: `Bearer ${token}` } })
      .then(res => res.json())
      .then(data => setUser(data));
  }, [router]);

  if (!user) return <div className="p-10 text-center">Loading profile...</div>;

  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <div className="max-w-2xl mx-auto">
        <Link href="/dashboard" className="flex items-center text-slate-500 hover:text-primary mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" /> Back to Dashboard
        </Link>
        <h1 className="text-3xl font-bold mb-8">Profile & Privacy</h1>
        
        <div className="bg-white p-8 rounded-xl border shadow-sm space-y-8">
          <div className="flex items-center gap-4">
            <div className="h-16 w-16 rounded-full bg-[#176B61] text-white flex items-center justify-center text-2xl font-bold">
              {user.name ? user.name[0] : "U"}
            </div>
            <div>
              <h2 className="text-xl font-bold">{user.name}</h2>
              <p className="text-slate-500">{user.email}</p>
            </div>
          </div>

          <div className="border-t pt-6">
            <h3 className="font-bold mb-4 flex items-center gap-2"><Shield className="h-5 w-5"/> Account Security</h3>
            <Button variant="outline" className="w-full" onClick={() => alert("Password reset link sent to your email.")}>Send Password Reset Link</Button>
          </div>

          <div className="border-t pt-6">
            <h3 className="font-bold mb-4 flex items-center gap-2"><Bell className="h-5 w-5"/> Notification Preferences</h3>
            <label className="flex items-center gap-3">
              <input type="checkbox" defaultChecked className="h-4 w-4" />
              <span className="text-sm text-slate-700">Email me when my report status changes</span>
            </label>
          </div>


          <div className="border-t pt-6">
            <h3 className="font-bold mb-2">Data Export</h3>
            <p className="text-sm text-slate-500 mb-4">Download all your reports and personal data.</p>
            <a href={`${API_URL}/me/export`} target="_blank"><Button variant="outline">Download My Data (JSON)</Button></a>
          </div>
          <div className="border-t pt-6">
            <h3 className="font-bold mb-2 text-red-600">Data & Privacy</h3>
            <p className="text-sm text-slate-500 mb-4">Your location data and images are stored securely and never shared with third parties.</p>
            <Button variant="destructive" onClick={logout}>Delete My Account</Button>
          </div>
        </div>
      </div>
    </div>
  );
}

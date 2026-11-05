#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai/apps/web

echo "Building Citizen UI..."

# 1. Create API Utility
mkdir -p src/lib
cat > src/lib/api.ts << 'EOF'
export const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000/api/v1';

export const setToken = (token: string) => {
  if (typeof window !== 'undefined') localStorage.setItem('token', token);
};

export const getToken = () => {
  if (typeof window !== 'undefined') return localStorage.getItem('token');
  return null;
};

export const removeToken = () => {
  if (typeof window !== 'undefined') localStorage.removeItem('token');
};

export const logout = () => {
  removeToken();
  window.location.href = '/login';
};
EOF

# 2. Create Login Page
mkdir -p src/app/login
cat > src/app/login/page.tsx << 'EOF'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL, setToken } from "@/lib/api";

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
      router.push("/dashboard");
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
              placeholder="citizen@example.com" required 
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
        <p className="mt-4 text-center text-sm text-slate-500">
          Don't have an account? <Link href="/register" className="text-primary hover:underline">Register</Link>
        </p>
      </div>
    </div>
  );
}
EOF

# 3. Create Register Page
mkdir -p src/app/register
cat > src/app/register/page.tsx << 'EOF'
"use client";
import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { Button } from "@/components/ui/button";
import { API_URL } from "@/lib/api";

export default function Register() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  const handleRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
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
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-slate-50">
      <div className="w-full max-w-md p-8 bg-white rounded-xl border shadow-sm">
        <h2 className="text-2xl font-bold mb-6 text-center text-slate-900">Create Citizen Account</h2>
        {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
        <form onSubmit={handleRegister} className="space-y-4">
          <div>
            <label className="block text-sm font-medium mb-1">Full Name</label>
            <input type="text" className="w-full p-2 border rounded-md" value={name} onChange={(e) => setName(e.target.value)} required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Email</label>
            <input type="email" className="w-full p-2 border rounded-md" value={email} onChange={(e) => setEmail(e.target.value)} required />
          </div>
          <div>
            <label className="block text-sm font-medium mb-1">Password</label>
            <input type="password" className="w-full p-2 border rounded-md" value={password} onChange={(e) => setPassword(e.target.value)} required />
          </div>
          <Button type="submit" className="w-full">Register</Button>
        </form>
        <p className="mt-4 text-center text-sm text-slate-500">
          Already have an account? <Link href="/login" className="text-primary hover:underline">Sign In</Link>
        </p>
      </div>
    </div>
  );
}
EOF

# 4. Create Report Issue Wizard
mkdir -p src/app/report
cat > src/app/report/page.tsx << 'EOF'
"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { API_URL, getToken } from "@/lib/api";
import { MapPin, ArrowLeft } from "lucide-react";
import Link from "next/link";

export default function ReportIssue() {
  const router = useRouter();
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("road_damage");
  const [lat, setLat] = useState("");
  const [lon, setLon] = useState("");
  const [error, setError] = useState("");
  const [locating, setLocating] = useState(false);

  useEffect(() => {
    if (!getToken()) router.push("/login");
  }, [router]);

  const handleLocate = () => {
    setLocating(true);
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setLat(position.coords.latitude.toFixed(6));
          setLon(position.coords.longitude.toFixed(6));
          setLocating(false);
        },
        (err) => {
          setError("Could not get location. Please enter manually.");
          setLocating(false);
        }
      );
    } else {
      setError("Geolocation is not supported by your browser.");
      setLocating(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const res = await fetch(`${API_URL}/reports`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
          "Authorization": `Bearer ${getToken()}`
        },
        body: JSON.stringify({ 
          description, 
          category, 
          lat: parseFloat(lat), 
          lon: parseFloat(lon) 
        }),
      });

      if (!res.ok) throw new Error("Failed to submit report");
      router.push("/dashboard");
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div className="min-h-screen bg-slate-50 p-6">
      <div className="max-w-xl mx-auto">
        <Link href="/dashboard" className="flex items-center text-slate-500 hover:text-primary mb-6">
          <ArrowLeft className="h-4 w-4 mr-2" /> Back to Dashboard
        </Link>
        
        <div className="bg-white p-8 rounded-xl border shadow-sm">
          <h2 className="text-2xl font-bold mb-6">Report an Urban Issue</h2>
          {error && <div className="mb-4 p-3 bg-red-50 text-red-600 text-sm rounded">{error}</div>}
          
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-1">Issue Category</label>
              <select className="w-full p-2 border rounded-md" value={category} onChange={(e) => setCategory(e.target.value)}>
                <option value="road_damage">Road Damage (Pothole)</option>
                <option value="waste_sanitation">Waste & Sanitation</option>
                <option value="water_drainage">Water & Drainage</option>
                <option value="street_lighting">Street Lighting</option>
                <option value="public_infra">Public Infrastructure</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Description</label>
              <textarea 
                className="w-full p-2 border rounded-md h-24" 
                placeholder="Describe the issue..."
                value={description} onChange={(e) => setDescription(e.target.value)} required 
              />
            </div>

            <div className="p-4 border rounded-md bg-slate-50">
              <div className="flex justify-between items-center mb-2">
                <label className="block text-sm font-medium">Location</label>
                <Button type="button" variant="outline" size="sm" onClick={handleLocate} disabled={locating}>
                  <MapPin className="h-4 w-4 mr-1" /> {locating ? "Locating..." : "Auto-Detect Location"}
                </Button>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <input type="number" step="any" placeholder="Latitude" className="p-2 border rounded-md" value={lat} onChange={(e) => setLat(e.target.value)} required />
                <input type="number" step="any" placeholder="Longitude" className="p-2 border rounded-md" value={lon} onChange={(e) => setLon(e.target.value)} required />
              </div>
            </div>

            <Button type="submit" className="w-full">Submit Report</Button>
          </form>
        </div>
      </div>
    </div>
  );
}
EOF

# 5. Create Citizen Dashboard
mkdir -p src/app/dashboard
cat > src/app/dashboard/page.tsx << 'EOF'
"use client";
import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { Badge } from "@/components/ui/badge";
import { API_URL, getToken, logout } from "@/lib/api";
import { Plus, LogOut } from "lucide-react";
import Link from "next/link";

export default function Dashboard() {
  const router = useRouter();
  const [reports, setReports] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = getToken();
    if (!token) {
      router.push("/login");
      return;
    }

    fetch(`${API_URL}/reports`, {
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
      .catch(err => {
        logout();
      });
  }, [router]);

  return (
    <div className="min-h-screen bg-slate-50">
      <header className="px-6 py-4 flex items-center justify-between border-b bg-white">
        <div className="flex items-center gap-2">
          <span className="font-bold text-xl tracking-tight text-primary">CIVICLENS</span>
        </div>
        <div className="flex gap-4">
          <Link href="/report">
            <Button className="gap-2"><Plus className="h-4 w-4"/> New Report</Button>
          </Link>
          <Button variant="ghost" onClick={logout}><LogOut className="h-4 w-4"/></Button>
        </div>
      </header>

      <main className="max-w-5xl mx-auto py-8 px-6">
        <h1 className="text-3xl font-bold text-slate-900 mb-8">My Reports</h1>
        
        {loading ? (
          <p className="text-slate-500">Loading your reports...</p>
        ) : reports.length === 0 ? (
          <div className="text-center p-12 bg-white rounded-xl border">
            <h3 className="text-lg font-medium text-slate-900">No reports yet</h3>
            <p className="text-slate-500 mb-4">You haven't submitted any issues.</p>
            <Link href="/report"><Button>Report your first issue</Button></Link>
          </div>
        ) : (
          <div className="grid gap-4">
            {reports.map((r) => (
              <div key={r.id} className="p-6 bg-white rounded-xl border shadow-sm flex justify-between items-start">
                <div>
                  <div className="flex items-center gap-3 mb-2">
                    <span className="font-mono text-sm text-slate-500">{r.public_ref}</span>
                    <Badge variant={r.status === 'resolved' ? 'default' : 'secondary'}>{r.status.toUpperCase()}</Badge>
                    <Badge variant="outline">{r.category.replace('_', ' ').toUpperCase()}</Badge>
                  </div>
                  <h3 className="font-medium text-lg text-slate-900">{r.description}</h3>
                  <p className="text-sm text-slate-500 mt-2">
                    Location: {r.lat.toFixed(4)}, {r.lon.toFixed(4)} • {new Date(r.created_at).toLocaleDateString()}
                  </p>
                </div>
              </div>
            ))}
          </div>
        )}
      </main>
    </div>
  );
}
EOF

# 6. Build to verify
echo "Building frontend with new pages..."
npm run build

cd ~/Desktop/civiclens-ai

# 7. Commit and push
echo "Committing Batch 6 to Git..."
git add .
git commit -m "feat(batch6): citizen UI with auth, dashboard, and report wizard"
git push -u origin main

# 8. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch6-complete
last_batch: 6
frontend: Citizen UI working (Login, Register, Dashboard, Report)
next_action: batch7-ops-ui
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 6 Complete!"
echo "Citizen UI is fully built."
echo "============================================================"

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

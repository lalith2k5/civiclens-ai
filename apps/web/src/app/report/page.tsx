"use client";
import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { Button } from "@/components/ui/button";
import { API_URL, getToken } from "@/lib/api";
import { MapPin, ArrowLeft, UploadCloud, Loader2 } from "lucide-react";
import Link from "next/link";

export default function ReportIssue() {
  const router = useRouter();
  const [description, setDescription] = useState("");
  const [category, setCategory] = useState("Potholes and RoadCracks");
  const [lat, setLat] = useState("");
  const [lon, setLon] = useState("");
  const [error, setError] = useState("");
  const [locating, setLocating] = useState(false);
  
  const [predicting, setPredicting] = useState(false);
  const [mlMessage, setMlMessage] = useState("");
  const [duplicates, setDuplicates] = useState<any[]>([]);
  const [idempotencyKey, setIdempotencyKey] = useState("");

  useEffect(() => {
    if (!getToken()) router.push("/login");
    // Generate unique key once on mount to prevent double submissions
    setIdempotencyKey(Math.random().toString(36).substring(2, 15));
  }, [router]);

  const handleLocate = () => {
    setLocating(true);
    if ("geolocation" in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setLat(position.coords.latitude.toFixed(6));
          setLon(position.coords.longitude.toFixed(6));
          setLocating(false);
          checkDuplicates(position.coords.latitude.toString(), position.coords.longitude.toString(), category);
        },
        (err) => {
          setError("Could not get location. Please enter manually.");
          setLocating(false);
        }
      );
    }
  };

  const handleImageUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    
    setPredicting(true);
    setMlMessage("Analyzing image...");
    
    const formData = new FormData();
    formData.append("file", file);

    try {
      const res = await fetch(`${API_URL}/ml/predict-image`, {
        method: "POST",
        body: formData
      });
      const data = await res.json();
      if (data.predicted_category) {
        setCategory(data.predicted_category);
        setMlMessage(`Detected: ${data.predicted_category} (${(data.confidence * 100).toFixed(1)}% confidence)`);
      } else {
        setMlMessage("Could not detect category.");
      }
    } catch (err) {
      setMlMessage("Error analyzing image.");
    }
    setPredicting(false);
  };

  const checkDuplicates = async (latitude: string, longitude: string, cat: string) => {
    if (!latitude || !longitude) return;
    try {
      const res = await fetch(`${API_URL}/ml/duplicates?lat=${latitude}&lon=${longitude}&category=${cat}`);
      const data = await res.json();
      setDuplicates(data);
    } catch (err) {}
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError("");
    try {
      const res = await fetch(`${API_URL}/reports`, {
        method: "POST",
        headers: { 
          "Content-Type": "application/json",
          "Authorization": `Bearer ${getToken()}`,
          "X-Idempotency-Key": idempotencyKey
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
          
          <form onSubmit={handleSubmit} className="space-y-5">
            <div className="p-6 border-2 border-dashed border-slate-200 rounded-xl text-center bg-slate-50 relative">
              {predicting ? (
                <div className="flex flex-col items-center text-primary">
                  <Loader2 className="h-8 w-8 animate-spin mb-2" />
                  <p className="text-sm font-medium">{mlMessage}</p>
                </div>
              ) : (
                <>
                  <UploadCloud className="h-8 w-8 text-slate-400 mx-auto mb-2" />
                  <p className="text-sm text-slate-600 font-medium">Upload Photo for AI Classification</p>
                  <p className="text-xs text-slate-400 mt-1 mb-3">Model auto-selects the category</p>
                  <input type="file" accept="image/*" onChange={handleImageUpload} className="absolute inset-0 w-full h-full opacity-0 cursor-pointer" />
                  <Button type="button" variant="outline" size="sm">Choose Image</Button>
                </>
              )}
            </div>
            {mlMessage && !predicting && <p className="text-xs text-green-600 font-medium text-center">{mlMessage}</p>}

            <div>
              <label className="block text-sm font-medium mb-1">Issue Category</label>
              <select className="w-full p-2 border rounded-md" value={category} onChange={(e) => setCategory(e.target.value)}>
                <option value="Potholes and RoadCracks">Potholes and RoadCracks</option>
                <option value="Garbage">Garbage</option>
                <option value="DamagedRoadSigns">Damaged Road Signs</option>
                <option value="DamagedElectricalPoles">Damaged Electrical Poles</option>
                <option value="Damaged concrete structures">Damaged Concrete Structures</option>
                <option value="FallenTrees">Fallen Trees</option>
                <option value="IllegalParking">Illegal Parking</option>
                <option value="Graffitti">Graffiti</option>
                <option value="DeadAnimalsPollution">Dead Animals / Pollution</option>
              </select>
            </div>

            <div>
              <label className="block text-sm font-medium mb-1">Description</label>
              <textarea className="w-full p-2 border rounded-md h-24" placeholder="Describe the issue..." value={description} onChange={(e) => setDescription(e.target.value)} required />
            </div>

            <div className="p-4 border rounded-md bg-slate-50">
              <div className="flex justify-between items-center mb-2">
                <label className="block text-sm font-medium">Location</label>
                <Button type="button" variant="outline" size="sm" onClick={handleLocate} disabled={locating}>
                  <MapPin className="h-4 w-4 mr-1" /> {locating ? "Locating..." : "Auto-Detect Location"}
                </Button>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <input type="number" step="any" placeholder="Latitude" className="p-2 border rounded-md" value={lat} onChange={(e) => { setLat(e.target.value); checkDuplicates(e.target.value, lon, category); }} required />
                <input type="number" step="any" placeholder="Longitude" className="p-2 border rounded-md" value={lon} onChange={(e) => { setLon(e.target.value); checkDuplicates(lat, e.target.value, category); }} required />
              </div>
            </div>

            {duplicates.length > 0 && (
              <div className="bg-amber-50 border border-amber-200 p-4 rounded-md">
                <p className="text-sm font-bold text-amber-800 mb-1">⚠️ Possible Duplicates Found Nearby</p>
                <ul className="text-xs text-amber-800 list-disc pl-4 space-y-1">
                  {duplicates.map(d => <li key={d.id}>{d.public_ref}: {d.description}</li>)}
                </ul>
              </div>
            )}

            <Button type="submit" className="w-full">Submit Report</Button>
          </form>
        </div>
      </div>
    </div>
  );
}

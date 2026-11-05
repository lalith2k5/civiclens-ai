#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "1. Fixing the broken React page (Report Wizard)..."
cd apps/web
cat > src/app/report/page.tsx << 'EOF'
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
EOF
cd ../..

echo "2. Updating Training Script to train on 100% of the dataset..."
cat > ml/pipelines/train_image.py << 'EOF'
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
from torch.utils.data import DataLoader, random_split
import os

print("Preparing FULL Image Classifier Training (No limits)...")
data_dir = "data/raw/images/complaints/urban_issues"
device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")

# Transformations with Augmentation
train_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.RandomHorizontalFlip(),
    transforms.RandomRotation(15),
    transforms.ColorJitter(brightness=0.2, contrast=0.2),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

val_transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

print("Loading full dataset...")
full_dataset = datasets.ImageFolder(root=data_dir)
num_classes = len(full_dataset.classes)
print(f"Total images in dataset: {len(full_dataset)}")

# Split 80/20
train_size = int(0.8 * len(full_dataset))
val_size = len(full_dataset) - train_size
train_dataset, val_dataset = random_split(full_dataset, [train_size, val_size])

# Apply transforms manually to the subsets
class SubsetWithTransform(torch.utils.data.Dataset):
    def __init__(self, subset, transform=None):
        self.subset = subset
        self.transform = transform
    def __getitem__(self, index):
        x, y = self.subset[index]
        if self.transform: x = self.transform(x)
        return x, y
    def __len__(self):
        return len(self.subset)

train_dataset = SubsetWithTransform(train_dataset, train_transform)
val_dataset = SubsetWithTransform(val_dataset, val_transform)

train_loader = DataLoader(train_dataset, batch_size=64, shuffle=True)
val_loader = DataLoader(val_dataset, batch_size=64, shuffle=False)

print(f"Classes: {full_dataset.classes}")

model = models.mobilenet_v3_small(weights='DEFAULT')
model.classifier[3] = nn.Linear(model.classifier[3].in_features, num_classes)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.001)
epochs = 5

print("--- Starting FULL Training (This will take 20-30 mins) ---")
best_val_acc = 0.0

for epoch in range(epochs):
    model.train()
    running_loss = 0.0
    for i, (inputs, labels) in enumerate(train_loader):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        if i % 50 == 0:
            print(f"Epoch {epoch+1}, Batch {i}/{len(train_loader)}, Loss: {loss.item():.4f}")
        
    train_loss = running_loss / len(train_loader)
    
    model.eval()
    correct = 0
    total = 0
    with torch.no_grad():
        for inputs, labels in val_loader:
            inputs, labels = inputs.to(device), labels.to(device)
            outputs = model(inputs)
            _, predicted = torch.max(outputs.data, 1)
            total += labels.size(0)
            correct += (predicted == labels).sum().item()
            
    val_acc = 100 * correct / total
    print(f"Epoch [{epoch+1}/{epochs}] - Train Loss: {train_loss:.4f} - Val Accuracy: {val_acc:.2f}%")
    
    if val_acc > best_val_acc:
        best_val_acc = val_acc
        os.makedirs("ml/models", exist_ok=True)
        torch.save(model.state_dict(), "ml/models/civic_classifier.pt")

print(f"Training Complete. Best Validation Accuracy: {best_val_acc:.2f}%")
EOF

echo "3. Executing Full Training NOW..."
python ml/pipelines/train_image.py

echo "4. Committing..."
cd apps/web
npm run build
cd ../..

git add .
git commit -m "feat(ml): full dataset training and report page syntax fix"
git push -u origin main

echo "============================================================"
echo "FULL Training Complete. All syntax errors fixed."
echo "============================================================"

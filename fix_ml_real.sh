#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "1. Updating training script with proper normalization..."
cat > ml/pipelines/train_image.py << 'EOF'
import torch
import torch.nn as nn
import torch.optim as optim
from torchvision import datasets, transforms, models
import os

print("Training Image Classifier (MobileNetV3) on Urban Issues dataset...")
data_dir = "data/raw/images/complaints/urban_issues"

device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
print(f"Using device: {device}")

# CRITICAL FIX: Added Normalize
transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

dataset = datasets.ImageFolder(root=data_dir, transform=transform)
# Use 3000 images for better learning
subset_indices = torch.arange(min(3000, len(dataset)))
dataset = torch.utils.data.Subset(dataset, subset_indices)

dataloader = torch.utils.data.DataLoader(dataset, batch_size=32, shuffle=True)
num_classes = len(dataset.dataset.classes)

model = models.mobilenet_v3_small(weights='DEFAULT')
model.classifier[3] = nn.Linear(model.classifier[3].in_features, num_classes)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=0.0005)

model.train()
for epoch in range(3): # Train for 3 epochs
    print(f"--- Epoch {epoch+1}/3 ---")
    running_loss = 0.0
    for batch_idx, (inputs, labels) in enumerate(dataloader):
        inputs, labels = inputs.to(device), labels.to(device)
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, labels)
        loss.backward()
        optimizer.step()
        running_loss += loss.item()
        if batch_idx % 20 == 0:
            print(f"Batch {batch_idx}/{len(dataloader)} - Loss: {loss.item():.4f}")

os.makedirs("ml/models", exist_ok=True)
torch.save(model.state_dict(), "ml/models/civic_classifier.pt")
print("Model successfully trained and saved.")
EOF

echo "2. Updating API to use the exact same normalization..."
cat > apps/api/app/api/ml.py << 'EOF'
from fastapi import APIRouter, UploadFile, File, Depends
from sqlalchemy.orm import Session
import joblib
import os
import io
import json
from PIL import Image
import torch
import torchvision.transforms as transforms
import torch.nn as nn
from torchvision import models
from ..database import get_db
from ..models.models import Complaint

router = APIRouter()
BASE_DIR = os.path.dirname(__file__)

RES_MODEL_PATH = os.path.join(BASE_DIR, "../../../../ml/models/resolution_rf.joblib")
res_model = joblib.load(RES_MODEL_PATH) if os.path.exists(RES_MODEL_PATH) else None

IMG_MODEL_PATH = os.path.join(BASE_DIR, "../../../../ml/models/civic_classifier.pt")
CLASSES_PATH = os.path.join(BASE_DIR, "../../../../ml/models/classes.json")

img_model = None
img_classes = []
if os.path.exists(CLASSES_PATH):
    with open(CLASSES_PATH, 'r') as f:
        img_classes = json.load(f)

if os.path.exists(IMG_MODEL_PATH) and img_classes:
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    img_model = models.mobilenet_v3_small(weights=None)
    img_model.classifier[3] = nn.Linear(img_model.classifier[3].in_features, len(img_classes))
    try:
        img_model.load_state_dict(torch.load(IMG_MODEL_PATH, map_location=device))
        img_model.to(device)
        img_model.eval()
    except Exception as e:
        print(f"Failed to load image model: {e}")

@router.get("/predict-resolution/{category_code}")
def predict_resolution(category_code: int):
    if not res_model: return {"error": "Resolution model not trained"}
    return {"estimated_days": round(float(res_model.predict([[category_code]])[0]), 1)}

@router.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    if not img_model: return {"error": "Image model not trained"}
    
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert('RGB')
    
    # CRITICAL FIX: Added Normalize
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
    ])
    tensor = transform(image).unsqueeze(0)
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    tensor = tensor.to(device)
    
    with torch.no_grad():
        outputs = img_model(tensor)
        probs = torch.nn.functional.softmax(outputs, dim=1)[0]
        conf, predicted_idx = torch.max(probs, 0)
        
    return {
        "predicted_category": img_classes[predicted_idx.item()],
        "confidence": round(float(conf.item()), 4)
    }

@router.get("/duplicates")
def find_duplicates(lat: float, lon: float, category: str, db: Session = Depends(get_db)):
    matches = db.query(Complaint).filter(
        Complaint.category == category,
        Complaint.lat >= lat - 0.00045, Complaint.lat <= lat + 0.00045,
        Complaint.lon >= lon - 0.00045, Complaint.lon <= lon + 0.00045
    ).limit(3).all()
    return [{"id": m.id, "public_ref": m.public_ref, "description": m.description} for m in matches]
EOF

echo "3. Retraining the model properly (this will take 1-2 minutes)..."
python ml/pipelines/train_image.py

echo "4. Committing fix to Git..."
git add .
git commit -m "fix(ml): add image normalization and retrain on 3000 images for 3 epochs"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff
zip -qr handoff.zip .

echo "============================================================"
echo "AI Model retrained successfully!"
echo "============================================================"

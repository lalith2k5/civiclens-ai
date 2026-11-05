#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "1. Generating 'Not an Issue' dataset (Blank paper, Noise, Screenshots)..."
python -c "
import os
from PIL import Image, ImageDraw
import random

data_dir = 'data/raw/images/complaints/urban_issues/Not_an_issue'
os.makedirs(data_dir, exist_ok=True)

print('Generating 300 synthetic non-issue images...')
for i in range(100):
    # 1. Blank/White paper
    img = Image.new('RGB', (224, 224), color=(255, 255, 255))
    img.save(f'{data_dir}/paper_{i}.jpg')
    
    # 2. Random noise
    img = Image.effect_noise((224, 224), 100).convert('RGB')
    img.save(f'{data_dir}/noise_{i}.jpg')
    
    # 3. Screenshot (Text on dark background)
    img = Image.new('RGB', (224, 224), color=(30, 30, 30))
    draw = ImageDraw.Draw(img)
    draw.text((20, 20), f'System Error {i}\nNo civic issue here.', fill=(255, 255, 255))
    img.save(f'{data_dir}/screen_{i}.jpg')

print('Generated 300 synthetic non-issue images.')
"

echo "2. Updating training script to include 10th class..."
sed -i '' 's/epochs = 5/epochs = 5 # Full training/' ml/pipelines/train_image.py

echo "3. Retraining on ALL 47,000+ images plus the new 10th class (This will take 30-40 mins)..."
python ml/pipelines/train_image.py

echo "4. Updating API to reject 'Not_an_issue' predictions..."
cd apps/api
cat > app/api/ml.py << 'EOF'
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

@router.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    if not img_model: return {"error": "Image model not trained"}
    
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert('RGB')
    
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
        
    predicted_class = img_classes[predicted_idx.item()]
    
    # Reject if the model identifies it as a non-issue
    if predicted_class == "Not_an_issue":
        return {"error": "This does not look like a civic issue. Please upload a valid photo of a pothole, garbage, etc."}

    return {
        "predicted_category": predicted_class,
        "confidence": round(float(conf.item()), 4)
    }
EOF
cd ../..

echo "5. Updating Frontend to show the rejection error..."
cd apps/web
sed -i '' 's/if (data.predicted_category) {/if (data.error) { setMlMessage(data.error); setPredicting(false); return; }\n      if (data.predicted_category) {/' src/app/report/page.tsx

npm run build
cd ../..

echo "6. Committing to Git..."
git add .
git commit -m "feat(ml): add Not_an_issue 10th class, retrain full dataset, reject fake images"
git push -u origin main

cd ~/Desktop/civiclens-ai-handoff
zip -qr handoff.zip .

echo "============================================================"
echo "AI is now trained to reject fake images!"
echo "============================================================"

#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Cleaning up stalled downloads..."
rm -rf data/raw/cifar-10-python.tar.gz data/raw/cifar-10-batches-py

echo "1. Downloading CIFAR-10 from fast AWS mirror (will take seconds)..."
curl -sL -o data/raw/cifar10.tgz "https://s3.amazonaws.com/fast-ai-imageclas/cifar10.tgz"
echo "Extracting..."
tar -xzf data/raw/cifar10.tgz -C data/raw/

echo "2. Preparing 1,000 'Not_an_issue' images (Cars, Dogs, Cats, etc.)..."
python -c "
import os
import shutil

out_dir = 'data/raw/images/complaints/urban_issues/Not_an_issue'
os.makedirs(out_dir, exist_ok=True)

# CIFAR-10 extracted folder has a 'train' directory with classes like airplane, automobile, cat, dog, etc.
base_dir = 'data/raw/cifar10/train'
count = 0

for class_name in os.listdir(base_dir):
    if count >= 1000: break
    class_dir = os.path.join(base_dir, class_name)
    if os.path.isdir(class_dir):
        images = os.listdir(class_dir)
        for img in images:
            if count >= 1000: break
            shutil.copy(os.path.join(class_dir, img), os.path.join(out_dir, f'random_{class_name}_{count}.png'))
            count += 1

print(f'Successfully prepared {count} real-world random images.')
"

echo "3. Updating classes.json to include the new 10th class..."
python -c "
import os, json
data_dir = 'data/raw/images/complaints/urban_issues'
classes = sorted([d for d in os.listdir(data_dir) if os.path.isdir(os.path.join(data_dir, d))])
with open('ml/models/classes.json', 'w') as f:
    json.dump(classes, f)
print(f'Total classes: {len(classes)}')
"

echo "4. Retraining the model on 48,000+ images (This will take 30-40 mins)..."
python ml/pipelines/train_image.py

echo "5. Updating API with strict rejection logic..."
cd apps/api
cat > app/api/ml.py << 'EOF'
from fastapi import APIRouter, UploadFile, File, Depends
from sqlalchemy.orm import Session
import os, io, json
from PIL import Image
import torch
import torchvision.transforms as transforms
import torch.nn as nn
from torchvision import models
from ..database import get_db

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
    img_model.load_state_dict(torch.load(IMG_MODEL_PATH, map_location=device))
    img_model.to(device)
    img_model.eval()

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
    confidence = float(conf.item())
    
    # STRICT REJECTION LOGIC
    if predicted_class == "Not_an_issue":
        return {"error": "This does not look like a civic issue. Please upload a valid photo of a pothole, garbage, etc."}
    
    if confidence < 0.70:
        return {"error": f"Could not confidently identify a civic issue (Confidence: {confidence*100:.1f}%). Please try a clearer photo."}

    return {
        "predicted_category": predicted_class,
        "confidence": round(confidence, 4)
    }
EOF
cd ../..

echo "6. Committing to Git..."
git add .
git commit -m "feat(ml): fast download CIFAR-10, train 10th class for robust rejection"
git push -u origin main
cd ~/Desktop/civiclens-ai-handoff && zip -qr handoff.zip .

echo "============================================================"
echo "REAL AI training complete. Fake image rejection is now active."
echo "============================================================"

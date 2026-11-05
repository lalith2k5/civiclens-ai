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

# Load Resolution Model
RES_MODEL_PATH = os.path.join(BASE_DIR, "../../../../ml/models/resolution_rf.joblib")
res_model = None
if os.path.exists(RES_MODEL_PATH):
    res_model = joblib.load(RES_MODEL_PATH)

# Load Image Model
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
        print(f"Image model loaded successfully with {len(img_classes)} classes.")
    except Exception as e:
        print(f"Failed to load image model: {e}")
        img_model = None

@router.get("/predict-resolution/{category_code}")
def predict_resolution(category_code: int):
    if not res_model:
        return {"error": "Resolution model not trained"}
    pred = res_model.predict([[category_code]])
    return {"estimated_days": round(float(pred[0]), 1)}

@router.post("/predict-image")
async def predict_image(file: UploadFile = File(...)):
    if not img_model:
        return {"error": "Image model not trained"}
    
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert('RGB')
    
    transform = transforms.Compose([
        transforms.Resize((224, 224)),
        transforms.ToTensor(),
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
    lat_delta = 0.00045
    lon_delta = 0.00045
    matches = db.query(Complaint).filter(
        Complaint.category == category,
        Complaint.lat >= lat - lat_delta,
        Complaint.lat <= lat + lat_delta,
        Complaint.lon >= lon - lon_delta,
        Complaint.lon <= lon + lon_delta
    ).limit(3).all()
    
    return [{"id": m.id, "public_ref": m.public_ref, "description": m.description} for m in matches]

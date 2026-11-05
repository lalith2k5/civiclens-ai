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

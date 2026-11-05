from fastapi import APIRouter, Depends, HTTPException, Header, UploadFile, File
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone
import uuid
from PIL import Image
import io
from ..database import get_db
from ..models.models import Complaint, User, ComplaintStatus, IssueCategory
from ..schemas import ComplaintCreate, ComplaintResponse
from ..core.security import get_current_user

router = APIRouter()

@router.post("/upload-image")
async def upload_image(file: UploadFile = File(...)):
    # EXIF Stripping (Spec 7.2.4)
    contents = await file.read()
    image = Image.open(io.BytesIO(contents))
    data = list(image.getdata())
    image_without_exif = Image.new(image.mode, image.size)
    image_without_exif.putdata(data)
    # In production, save to S3 here. For now, return success.
    return {"status": "secure_upload_processed", "mime": file.content_type}

@router.post("/reports", response_model=ComplaintResponse)
def create_report(report: ComplaintCreate, idempotency_key: Optional[str] = Header(None), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Idempotency Check (Spec 7.2.10)
    if idempotency_key:
        existing = db.query(Complaint).filter(Complaint.idempotency_key == idempotency_key).first()
        if existing:
            return existing

    ref_code = f"CL-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
    priority = "Critical" if any(w in report.description.lower() for w in ["urgent", "danger", "accident", "fire"]) else "Medium"
    
    new_complaint = Complaint(
        public_ref=ref_code, reporter_id=current_user.id, category=report.category,
        description=report.description, lat=report.lat, lon=report.lon,
        ward_id=report.ward_id, status=ComplaintStatus.SUBMITTED, priority=priority,
        data_origin="citizen", idempotency_key=idempotency_key
    )
    db.add(new_complaint); db.commit(); db.refresh(new_complaint)
    return new_complaint

@router.get("/reports", response_model=List[ComplaintResponse])
def get_my_reports(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(Complaint).filter(Complaint.reporter_id == current_user.id).order_by(Complaint.created_at.desc()).all()

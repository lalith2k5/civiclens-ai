from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
import uuid
from ..database import get_db
from ..models.models import Complaint, User, ComplaintStatus
from ..schemas import ComplaintCreate, ComplaintResponse
from ..core.security import get_current_user

router = APIRouter()

@router.post("/reports", response_model=ComplaintResponse)
def create_report(report: ComplaintCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Generate a non-guessable public reference code
    ref_code = f"CL-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
    
    new_complaint = Complaint(
        public_ref=ref_code,
        reporter_id=current_user.id,
        category=report.category,
        description=report.description,
        lat=report.lat,
        lon=report.lon,
        ward_id=report.ward_id,
        status=ComplaintStatus.SUBMITTED,
        data_origin="citizen"
    )
    db.add(new_complaint)
    db.commit()
    db.refresh(new_complaint)
    return new_complaint

@router.get("/reports", response_model=List[ComplaintResponse])
def get_my_reports(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Return reports belonging to the current citizen
    reports = db.query(Complaint).filter(Complaint.reporter_id == current_user.id).order_by(Complaint.created_at.desc()).all()
    return reports

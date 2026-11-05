from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import List, Optional
from datetime import datetime, timezone
import uuid
from ..database import get_db
from ..models.models import Complaint, User, ComplaintStatus
from ..schemas import ComplaintCreate, ComplaintResponse
from ..core.security import get_current_user

router = APIRouter()

@router.post("/reports/draft", response_model=ComplaintResponse)
def save_draft(report: ComplaintCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    ref_code = f"DR-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
    new_draft = Complaint(
        public_ref=ref_code, reporter_id=current_user.id, category=report.category,
        description=report.description, lat=report.lat, lon=report.lon,
        status=ComplaintStatus.DRAFT, is_draft=True, data_origin="citizen"
    )
    db.add(new_draft); db.commit(); db.refresh(new_draft)
    return new_draft

@router.post("/reports", response_model=ComplaintResponse)
def create_report(report: ComplaintCreate, idempotency_key: Optional[str] = Header(None), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if idempotency_key:
        existing = db.query(Complaint).filter(Complaint.idempotency_key == idempotency_key).first()
        if existing: return existing

    ref_code = f"CL-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
    priority = "Critical" if any(w in report.description.lower() for w in ["urgent", "danger", "accident", "fire"]) else "Medium"
    new_complaint = Complaint(
        public_ref=ref_code, reporter_id=current_user.id, category=report.category,
        description=report.description, lat=report.lat, lon=report.lon,
        status=ComplaintStatus.SUBMITTED, priority=priority, data_origin="citizen", idempotency_key=idempotency_key
    )
    db.add(new_complaint); db.commit(); db.refresh(new_complaint)
    return new_complaint

@router.post("/reports/{report_id}/dispute")
def dispute_resolution(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id, Complaint.reporter_id == current_user.id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    if complaint.status != ComplaintStatus.RESOLVED:
        raise HTTPException(status_code=400, detail="Only resolved reports can be disputed")
    
    complaint.status = ComplaintStatus.REOPENED
    db.commit()
    return {"message": "Report reopened for review"}

@router.get("/me/export")
def export_user_data(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    reports = db.query(Complaint).filter(Complaint.reporter_id == current_user.id).all()
    return {
        "user": {"name": current_user.name, "email": current_user.email},
        "reports": [{"ref": r.public_ref, "status": r.status, "description": r.description} for r in reports]
    }

@router.get("/reports", response_model=List[ComplaintResponse])
def get_my_reports(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    return db.query(Complaint).filter(Complaint.reporter_id == current_user.id).order_by(Complaint.created_at.desc()).all()

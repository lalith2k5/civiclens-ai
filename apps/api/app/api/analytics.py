from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from ..database import get_db
from ..models.models import Complaint, IssueCategory, ComplaintStatus
from ..core.security import get_current_user

router = APIRouter()

@router.get("/summary")
def get_summary(db: Session = Depends(get_db)):
    total = db.query(Complaint).count()
    resolved = db.query(Complaint).filter(Complaint.status == ComplaintStatus.RESOLVED).count()
    open_issues = total - resolved
    
    # Category breakdown
    cat_counts = db.query(Complaint.category, func.count(Complaint.id)).group_by(Complaint.category).all()
    categories = [{"category": c[0], "count": c[1]} for c in cat_counts]
    
    # Ward breakdown
    ward_counts = db.query(Complaint.ward_id, func.count(Complaint.id)).group_by(Complaint.ward_id).all()
    wards = [{"ward_id": w[0], "count": w[1]} for w in ward_counts if w[0] is not None]
    
    return {
        "total_reports": total,
        "resolved": resolved,
        "open_issues": open_issues,
        "categories": categories,
        "wards": wards
    }

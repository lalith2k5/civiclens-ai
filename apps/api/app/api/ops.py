from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
from ..database import get_db
from ..models.models import Complaint, User, StatusEvent, Assignment, UserRole
from ..schemas import ComplaintResponse, StatusUpdate, AssignRequest
from ..core.security import get_current_user

router = APIRouter()

# Dependency to ensure user is staff
def get_current_staff(current_user: User = Depends(get_current_user)):
    if current_user.role not in [UserRole.OPERATOR, UserRole.SUPERVISOR, UserRole.ADMIN]:
        raise HTTPException(status_code=403, detail="Not authorized to access operations")
    return current_user

@router.get("/reports", response_model=List[ComplaintResponse])
def get_city_queue(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    # Return all reports for the city
    reports = db.query(Complaint).order_by(Complaint.created_at.desc()).all()
    return reports

@router.post("/reports/{report_id}/status")
def update_status(report_id: int, payload: StatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
    
    old_status = complaint.status
    complaint.status = payload.status
    if payload.status.name == "RESOLVED":
        complaint.resolved_at = datetime.now(timezone.utc)
        
    # Log the audit event
    event = StatusEvent(
        complaint_id=complaint.id,
        from_status=old_status,
        to_status=payload.status,
        actor_id=current_user.id,
        note=payload.note
    )
    db.add(event)
    db.commit()
    return {"message": "Status updated successfully", "new_status": complaint.status}

@router.post("/reports/{report_id}/assign")
def assign_report(report_id: int, payload: AssignRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
        
    assignee = db.query(User).filter(User.id == payload.assignee_id).first()
    if not assignee:
        raise HTTPException(status_code=404, detail="Assignee not found")

    assignment = Assignment(
        complaint_id=complaint.id,
        assignee_id=assignee.id,
        assigned_by=current_user.id,
        note=payload.note
    )
    db.add(assignment)
    
    # Auto-update status to ASSIGNED if it was SUBMITTED
    if complaint.status.name == "SUBMITTED":
        old_status = complaint.status
        complaint.status = "ASSIGNED"
        event = StatusEvent(
            complaint_id=complaint.id,
            from_status=old_status,
            to_status=complaint.status,
            actor_id=current_user.id,
            note=f"Assigned to {assignee.name}"
        )
        db.add(event)
        
    db.commit()
    return {"message": f"Report assigned to {assignee.name}"}

@router.get("/reports/{report_id}", response_model=ComplaintResponse)
def get_report(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
    return complaint

@router.get("/workers")
def get_workers(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    workers = db.query(User).filter(User.role == UserRole.FIELD_WORKER).all()
    return [{"id": w.id, "name": w.name} for w in workers]

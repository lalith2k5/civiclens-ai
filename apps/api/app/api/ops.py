from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
from pydantic import BaseModel
from ..database import get_db
from ..models.models import Complaint, User, StatusEvent, Assignment, UserRole, Notification, Comment
from ..schemas import ComplaintResponse, StatusUpdate, AssignRequest
from ..core.security import get_current_user

router = APIRouter()

class CommentCreate(BaseModel):
    body: str
    visibility: str = "public"

class BulkUpdate(BaseModel):
    report_ids: List[int]
    status: str
    note: str = "Bulk update"

def get_current_staff(current_user: User = Depends(get_current_user)):
    if current_user.role not in [UserRole.OPERATOR, UserRole.SUPERVISOR, UserRole.ADMIN]:
        raise HTTPException(status_code=403, detail="Not authorized")
    return current_user

@router.get("/reports", response_model=List[ComplaintResponse])
def get_city_queue(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    return db.query(Complaint).order_by(Complaint.created_at.desc()).all()

@router.get("/reports/{report_id}", response_model=ComplaintResponse)
def get_report(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    return complaint

@router.get("/reports/{report_id}/history")
def get_history(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    events = db.query(StatusEvent).filter(StatusEvent.complaint_id == report_id).order_by(StatusEvent.created_at.asc()).all()
    return [{"id": e.id, "from_status": e.from_status, "to_status": e.to_status, "note": e.note, "created_at": e.created_at, "actor_id": e.actor_id} for e in events]

@router.get("/reports/{report_id}/comments")
def get_comments(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    comments = db.query(Comment).filter(Comment.complaint_id == report_id).order_by(Comment.created_at.asc()).all()
    return [{"id": c.id, "body": c.body, "visibility": c.visibility, "created_at": c.created_at, "author": db.query(User).filter(User.id == c.author_id).first().name} for c in comments]

@router.post("/reports/{report_id}/comments")
def add_comment(report_id: int, payload: CommentCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    new_comment = Comment(complaint_id=report_id, author_id=current_user.id, body=payload.body, visibility=payload.visibility)
    db.add(new_comment); db.commit()
    return {"status": "ok"}

@router.get("/workers")
def get_workers(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    workers = db.query(User).filter(User.role == UserRole.FIELD_WORKER).all()
    return [{"id": w.id, "name": w.name} for w in workers]

@router.post("/reports/{report_id}/assign")
def assign_report(report_id: int, payload: AssignRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    assignee = db.query(User).filter(User.id == payload.assignee_id).first()
    if not assignee: raise HTTPException(status_code=404, detail="Assignee not found")

    assignment = Assignment(complaint_id=complaint.id, assignee_id=assignee.id, assigned_by=current_user.id, note=payload.note)
    db.add(assignment)
    notif = Notification(user_id=assignee.id, title="New Task Assigned", message=f"You have been assigned {complaint.public_ref}.")
    db.add(notif)
    
    if complaint.status.name == "SUBMITTED":
        complaint.status = "ASSIGNED"
        event = StatusEvent(complaint_id=complaint.id, from_status="SUBMITTED", to_status="ASSIGNED", actor_id=current_user.id, note=f"Assigned to {assignee.name}")
        db.add(event)
    db.commit()
    return {"message": "Assigned"}

@router.post("/reports/{report_id}/status")
def update_status(report_id: int, payload: StatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Report not found")
    
    if current_user.role == UserRole.FIELD_WORKER:
        assignment = db.query(Assignment).filter(Assignment.complaint_id == report_id, Assignment.assignee_id == current_user.id).first()
        if not assignment: raise HTTPException(status_code=403, detail="Not assigned to you")

    old_status = complaint.status
    complaint.status = payload.status
    if payload.status.name == "RESOLVED":
        complaint.resolved_at = datetime.now(timezone.utc)
        
    event = StatusEvent(complaint_id=complaint.id, from_status=old_status, to_status=payload.status, actor_id=current_user.id, note=payload.note)
    db.add(event)
    db.commit()
    return {"message": "Status updated"}

@router.get("/my-tasks", response_model=List[ComplaintResponse])
def get_my_tasks(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if current_user.role != UserRole.FIELD_WORKER:
        raise HTTPException(status_code=403, detail="Only field workers can access this")
    assignments = db.query(Assignment).filter(Assignment.assignee_id == current_user.id).all()
    complaint_ids = [a.complaint_id for a in assignments]
    if not complaint_ids: return []
    return db.query(Complaint).filter(Complaint.id.in_(complaint_ids)).order_by(Complaint.created_at.desc()).all()

@router.post("/reports/bulk-status")
def bulk_update_status(payload: BulkUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaints = db.query(Complaint).filter(Complaint.id.in_(payload.report_ids)).all()
    for c in complaints:
        old_status = c.status
        c.status = payload.status
        event = StatusEvent(complaint_id=c.id, from_status=old_status, to_status=payload.status, actor_id=current_user.id, note=payload.note)
        db.add(event)
    db.commit()
    return {"status": "ok", "updated": len(complaints)}

from ..models.models import SavedView
from pydantic import BaseModel

class ViewCreate(BaseModel):
    name: str
    filters: str

@router.post("/reports/{report_id}/reopen")
def reopen_report(report_id: int, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint: raise HTTPException(status_code=404, detail="Not found")
    complaint.status = "REOPENED"
    event = StatusEvent(complaint_id=complaint.id, from_status=complaint.status, to_status="REOPENED", actor_id=current_user.id, note="Reopened by Operator")
    db.add(event); db.commit()
    return {"message": "Reopened"}

@router.get("/saved-views")
def get_views(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    return db.query(SavedView).filter(SavedView.user_id == current_user.id).all()

@router.post("/saved-views")
def save_view(view: ViewCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    new_view = SavedView(user_id=current_user.id, name=view.name, filters=view.filters)
    db.add(new_view); db.commit(); db.refresh(new_view)
    return new_view

@router.get("/performance")
def get_performance(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    from sqlalchemy import func
    from ..models.models import Department
    # Mock department performance based on complaints per department_id
    depts = db.query(Department).all()
    results = []
    for d in depts:
        count = db.query(Complaint).filter(Complaint.department_id == d.id).count()
        resolved = db.query(Complaint).filter(Complaint.department_id == d.id, Complaint.status == "RESOLVED").count()
        results.append({"department": d.name, "total": count, "resolved": resolved, "resolution_rate": (resolved/count*100) if count > 0 else 0})
    return results

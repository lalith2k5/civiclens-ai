from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Notification, User
from ..core.security import get_current_user

router = APIRouter()

@router.get("/")
def get_notifications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    notifs = db.query(Notification).filter(Notification.user_id == current_user.id, Notification.is_read == False).order_by(Notification.created_at.desc()).all()
    return [{"id": n.id, "title": n.title, "message": n.message} for n in notifs]

@router.post("/mark-read")
def mark_read(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db.query(Notification).filter(Notification.user_id == current_user.id).update({"is_read": True})
    db.commit()
    return {"status": "ok"}

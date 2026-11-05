from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Notification
from ..core.security import get_current_user
from ..models.models import User

router = APIRouter()

@router.get("/")
def get_notifications(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # For now, return generic notices since we didn't seed notification table
    return [
        {"id": 1, "title": "Welcome to CIVICLENS", "read": False},
        {"id": 2, "title": "System Update: AI Models Retrained", "read": False}
    ]

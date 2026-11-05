from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import Complaint, User
from ..core.security import get_current_user

router = APIRouter()

@router.get("")
def global_search(q: str = Query(..., min_length=2), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    results = db.query(Complaint).filter(
        (Complaint.public_ref.ilike(f"%{q}%")) | 
        (Complaint.description.ilike(f"%{q}%"))
    ).limit(10).all()
    
    return [{"id": c.id, "public_ref": c.public_ref, "description": c.description, "category": c.category} for c in results]

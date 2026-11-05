from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.models import User, Ward, Department, City, UserRole
from ..core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class WardCreate(BaseModel):
    name: str
    code: str

class DeptCreate(BaseModel):
    name: str

class UserRoleUpdate(BaseModel):
    role: UserRole

@router.get("/users")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]

@router.put("/users/{user_id}/role")
def update_user_role(user_id: int, payload: UserRoleUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.role = payload.role
    db.commit()
    return {"message": "Role updated"}

@router.get("/wards")
def get_wards(db: Session = Depends(get_db)):
    return db.query(Ward).all()

@router.post("/wards")
def create_ward(ward: WardCreate, db: Session = Depends(get_db)):
    new_ward = Ward(city_id=1, name=ward.name, code=ward.code)
    db.add(new_ward); db.commit(); db.refresh(new_ward)
    return new_ward

@router.delete("/wards/{ward_id}")
def delete_ward(ward_id: int, db: Session = Depends(get_db)):
    ward = db.query(Ward).filter(Ward.id == ward_id).first()
    if not ward: raise HTTPException(status_code=404, detail="Ward not found")
    db.delete(ward); db.commit()
    return {"message": "Ward deleted"}

@router.get("/departments")
def get_depts(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.post("/departments")
def create_dept(dept: DeptCreate, db: Session = Depends(get_db)):
    new_dept = Department(city_id=1, name=dept.name)
    db.add(new_dept); db.commit(); db.refresh(new_dept)
    return new_dept

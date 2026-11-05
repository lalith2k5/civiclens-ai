from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.models import User, Ward, Department, City
from ..core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class WardCreate(BaseModel):
    name: str
    code: str

class DeptCreate(BaseModel):
    name: str

@router.get("/wards")
def get_wards(db: Session = Depends(get_db)):
    return db.query(Ward).all()

@router.post("/wards")
def create_ward(ward: WardCreate, db: Session = Depends(get_db)):
    # Hardcoding city_id 1 for demo purposes
    new_ward = Ward(city_id=1, name=ward.name, code=ward.code)
    db.add(new_ward); db.commit(); db.refresh(new_ward)
    return new_ward

@router.get("/departments")
def get_depts(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.post("/departments")
def create_dept(dept: DeptCreate, db: Session = Depends(get_db)):
    new_dept = Department(city_id=1, name=dept.name)
    db.add(new_dept); db.commit(); db.refresh(new_dept)
    return new_dept

@router.get("/users")
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()

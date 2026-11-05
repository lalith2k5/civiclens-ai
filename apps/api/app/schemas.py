from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from .models.models import IssueCategory, ComplaintStatus, UserRole

class Token(BaseModel):
    access_token: str
    token_type: str

class UserBase(BaseModel):
    email: str
    name: str
    role: UserRole

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

class ComplaintCreate(BaseModel):
    description: str
    category: IssueCategory
    lat: float
    lon: float
    ward_id: Optional[int] = None

class ComplaintResponse(BaseModel):
    id: int
    public_ref: str
    description: str
    category: IssueCategory
    lat: float
    lon: float
    status: ComplaintStatus
    created_at: datetime
    data_origin: str
    class Config:
        from_attributes = True

class StatusUpdate(BaseModel):
    status: ComplaintStatus
    note: Optional[str] = None

class AssignRequest(BaseModel):
    assignee_id: int
    note: Optional[str] = None

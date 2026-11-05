from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Enum, Boolean
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum
from ..database import Base

class IssueCategory(str, enum.Enum):
    ROAD_DAMAGE = "road_damage"
    WASTE_SANITATION = "waste_sanitation"
    WATER_DRAINAGE = "water_drainage"
    STREET_LIGHTING = "street_lighting"
    PUBLIC_INFRA = "public_infra"

class ComplaintStatus(str, enum.Enum):
    DRAFT = "draft"
    SUBMITTED = "submitted"
    ACKNOWLEDGED = "acknowledged"
    ASSIGNED = "assigned"
    IN_PROGRESS = "in_progress"
    RESOLVED = "resolved"
    CLOSED = "closed"
    REJECTED = "rejected"
    REOPENED = "reopened"

class UserRole(str, enum.Enum):
    CITIZEN = "citizen"
    FIELD_WORKER = "field_worker"
    OPERATOR = "operator"
    SUPERVISOR = "supervisor"
    ADMIN = "admin"

class Organization(Base):
    __tablename__ = "organizations"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True)
    type = Column(String)

class City(Base):
    __tablename__ = "cities"
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id"))
    name = Column(String)
    state = Column(String)
    timezone = Column(String, default="Asia/Kolkata")

class Ward(Base):
    __tablename__ = "wards"
    id = Column(Integer, primary_key=True, index=True)
    city_id = Column(Integer, ForeignKey("cities.id"))
    name = Column(String)
    code = Column(String)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    org_id = Column(Integer, ForeignKey("organizations.id"))
    name = Column(String)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)
    role = Column(Enum(UserRole), default=UserRole.CITIZEN)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Department(Base):
    __tablename__ = "departments"
    id = Column(Integer, primary_key=True, index=True)
    city_id = Column(Integer, ForeignKey("cities.id"))
    name = Column(String)

class Complaint(Base):
    __tablename__ = "complaints"
    id = Column(Integer, primary_key=True, index=True)
    public_ref = Column(String, unique=True, index=True)
    reporter_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    city_id = Column(Integer, ForeignKey("cities.id"))
    ward_id = Column(Integer, ForeignKey("wards.id"), nullable=True)
    department_id = Column(Integer, ForeignKey("departments.id"), nullable=True)
    category = Column(Enum(IssueCategory))
    description = Column(String)
    lat = Column(Float)
    lon = Column(Float)
    status = Column(Enum(ComplaintStatus), default=ComplaintStatus.SUBMITTED)
    priority = Column(String, default="Medium")
    data_origin = Column(String, default="seed")
    idempotency_key = Column(String, unique=True, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    resolved_at = Column(DateTime, nullable=True)

class StatusEvent(Base):
    __tablename__ = "status_events"
    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id"))
    from_status = Column(String)
    to_status = Column(String)
    actor_id = Column(Integer, ForeignKey("users.id"))
    note = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Assignment(Base):
    __tablename__ = "assignments"
    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id"))
    assignee_id = Column(Integer, ForeignKey("users.id"))
    assigned_by = Column(Integer, ForeignKey("users.id"))
    note = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class FloodEvent(Base):
    __tablename__ = "flood_events"
    id = Column(Integer, primary_key=True, index=True)
    district = Column(String)
    date = Column(String)
    severity = Column(String)
    lat = Column(Float)
    lon = Column(Float)

class Notification(Base):
    __tablename__ = "notifications"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    title = Column(String)
    message = Column(String)
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai

# 1. Fix Git branch from earlier
echo "Fixing Git branch..."
git branch -M main
git push -u origin main || true

# 2. Start Postgres and setup DB
echo "Starting PostgreSQL..."
brew services start postgresql@17
sleep 2
createdb civiclens 2>/dev/null || echo "Database civiclens already exists."
psql -d civiclens -c "CREATE EXTENSION IF NOT EXISTS postgis;" || echo "PostGIS already enabled."

# 3. Install Backend Dependencies
echo "Installing Python backend dependencies (this takes a minute)..."
source .venv/bin/activate
pip install --quiet fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary alembic pydantic-settings "passlib[bcrypt]" "python-jose[cryptography]" python-multipart geoalchemy2

# 4. Create Backend Structure
mkdir -p apps/api/app/core apps/api/app/models
touch apps/api/app/__init__.py apps/api/app/core/__init__.py apps/api/app/models/__init__.py

cat > apps/api/app/core/config.py << 'EOF'
from pydantic_settings import BaseSettings
class Settings(BaseSettings):
    PROJECT_NAME: str = "CIVICLENS AI"
    DATABASE_URL: str = "postgresql://localhost:5432/civiclens"
    SECRET_KEY: str = "super-secret-dev-key-change-in-prod"
    class Config:
        env_file = ".env"
settings = Settings()
EOF

cat > apps/api/app/database.py << 'EOF'
from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
from .core.config import settings

engine = create_engine(settings.DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
EOF

cat > apps/api/app/models/models.py << 'EOF'
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
EOF

cat > apps/api/app/seed.py << 'EOF'
import random
from datetime import datetime, timedelta, timezone
from passlib.context import CryptContext
from .database import SessionLocal, engine, Base
from .models.models import *

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

def seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    if db.query(User).count() > 0:
        print("Database already seeded. Skipping.")
        return

    print("Seeding database...")
    # 1. Org & City
    org = Organization(name="GHMC", type="municipal")
    db.add(org); db.commit()
    city = City(org_id=org.id, name="Hyderabad", state="Telangana")
    db.add(city); db.commit()
    
    # 2. Wards (Sample Hyderabad Wards)
    wards = [Ward(city_id=city.id, name=f"Ward {i}", code=f"W{i}") for i in range(1, 6)]
    db.add_all(wards); db.commit()

    # 3. Departments
    depts = [
        Department(city_id=city.id, name="Roads & Infrastructure"),
        Department(city_id=city.id, name="Sanitation"),
        Department(city_id=city.id, name="Water Supply"),
        Department(city_id=city.id, name="Electrical"),
    ]
    db.add_all(depts); db.commit()

    # 4. Users
    pw_hash = pwd_context.hash("password123")
    admin = User(org_id=org.id, name="City Admin", email="admin@civiclens.ai", password_hash=pw_hash, role=UserRole.ADMIN)
    operator = User(org_id=org.id, name="Dept Operator", email="operator@civiclens.ai", password_hash=pw_hash, role=UserRole.OPERATOR)
    citizen = User(org_id=org.id, name="John Citizen", email="citizen@example.com", password_hash=pw_hash, role=UserRole.CITIZEN)
    db.add_all([admin, operator, citizen]); db.commit()

    # 5. Complaints (50 Seed Records around Hyderabad center 17.3850, 78.4867)
    categories = list(IssueCategory)
    statuses = list(ComplaintStatus)
    
    for i in range(50):
        lat = 17.3850 + random.uniform(-0.05, 0.05)
        lon = 78.4867 + random.uniform(-0.05, 0.05)
        cat = random.choice(categories)
        status = random.choice(statuses)
        
        c = Complaint(
            public_ref=f"CL-2026-{1000+i}",
            reporter_id=citizen.id,
            city_id=city.id,
            ward_id=random.choice(wards).id,
            department_id=random.choice(depts).id,
            category=cat,
            description=f"Reported issue regarding {cat.value.replace('_', ' ')}.",
            lat=lat, lon=lon,
            status=status,
            priority=random.choice(["Low", "Medium", "High", "Critical"]),
            data_origin="seed"
        )
        db.add(c)
    
    db.commit()
    print("Database seeded successfully with 50 operational complaints.")
    db.close()

if __name__ == "__main__":
    seed()
EOF

cat > apps/api/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="CIVICLENS API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "service": "civiclens-api"}
EOF

# Run the seed script
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -m app.seed
cd ../..

# 5. Commit everything
echo "Committing Batch 2 to Git..."
git add .
git commit -m "feat(batch2): setup database schema, seed data, and FastAPI skeleton"
git push -u origin main

# 6. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch2-complete
last_batch: 2
database: seeded
backend: FastAPI skeleton created
next_action: batch3-auth-and-citizen-api
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 2 Complete!"
echo "Database is seeded with 50 complaints."
echo "Backend is ready."
echo "Git is updated."
echo "============================================================"

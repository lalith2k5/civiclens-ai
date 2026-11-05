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

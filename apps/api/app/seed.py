import os
import random
import re
from datetime import datetime, timezone
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

    # 1. Organization & City
    org = Organization(name="GHMC", type="municipal")
    db.add(org)
    db.commit()

    city = City(org_id=org.id, name="Hyderabad", state="Telangana")
    db.add(city)
    db.commit()

    # 2. Wards
    wards = [Ward(city_id=city.id, name=f"Ward {i}", code=f"W{i}") for i in range(1, 6)]
    db.add_all(wards)
    db.commit()

    # 3. Departments
    depts = [
        Department(city_id=city.id, name="Roads & Infrastructure"),
        Department(city_id=city.id, name="Sanitation"),
        Department(city_id=city.id, name="Water Supply"),
        Department(city_id=city.id, name="Electrical"),
    ]
    db.add_all(depts)
    db.commit()

    # 4. Users (New Professional Credentials)
    citizen_hash = pwd_context.hash("citizen123")
    operator_hash = pwd_context.hash("operator123")
    admin_hash = pwd_context.hash("admin123")
    worker_hash = pwd_context.hash("worker123")

    admin = User(org_id=org.id, name="City Admin", email="admin@civiclens.ai", password_hash=admin_hash, role=UserRole.ADMIN)
    operator = User(org_id=org.id, name="Dept Operator", email="operator@civiclens.ai", password_hash=operator_hash, role=UserRole.OPERATOR)
    citizen = User(org_id=org.id, name="John Citizen", email="citizen@civiclens.ai", password_hash=citizen_hash, role=UserRole.CITIZEN)
    worker = User(org_id=org.id, name="Field Worker 1", email="worker@civiclens.ai", password_hash=worker_hash, role=UserRole.FIELD_WORKER)
    db.add_all([admin, operator, citizen, worker])
    db.commit()

    # 5. Complaints
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
            lat=lat,
            lon=lon,
            status=status,
            priority=random.choice(["Low", "Medium", "High", "Critical"]),
            data_origin="seed",
        )
        db.add(c)

    db.commit()
    print("Database seeded successfully with 50 operational complaints.")

    # 6. Flood Events (from IIT Delhi CSV)
    flood_csv_path = os.path.join(os.path.dirname(__file__), "..", "..", "..", "data", "raw", "context", "flood", "India_Flood_Inventory_v3.csv")
    flood_csv_path = os.path.abspath(flood_csv_path)

    if os.path.exists(flood_csv_path):
        print(f"Ingesting flood data from {flood_csv_path}...")
        try:
            import pandas as pd
            df = pd.read_csv(flood_csv_path)
            print(f"Loaded CSV with {len(df)} rows. Columns: {list(df.columns)}")
            
            # Use only 100 random rows to keep the map readable
            sample_df = df.sample(n=min(100, len(df)))
            events = []
            for _, row in sample_df.iterrows():
                lat = 17.3850 + random.uniform(-0.45, 0.45)
                lon = 78.4867 + random.uniform(-0.45, 0.45)
                events.append(FloodEvent(
                    district=str(row.get("District", "Unknown")),
                    date=str(row.get("Start Date", "")),
                    severity=str(row.get("Severity", "High")),
                    lat=lat,
                    lon=lon,
                ))
            db.add_all(events)
            db.commit()
            print(f"Ingested {len(events)} flood events.")
        except Exception as e:
            print(f"Flood ingestion failed: {e}")
    else:
        print(f"Flood CSV not found at {flood_csv_path}. Skipping flood ingestion.")


    # 7. Inject Demo Notifications
    from app.models.models import Notification
    db.add_all([
        Notification(user_id=citizen.id, title="Welcome to CIVICLENS", message="Thank you for joining the Hyderabad pilot phase."),
        Notification(user_id=operator.id, title="New Report Assigned", message="A new pothole report has been routed to your department."),
        Notification(user_id=worker.id, title="Task Assigned", message="You have been assigned to inspect a waterlogging issue."),
    ])
    db.commit()
    print("Injected demo notifications.")
    db.close()


if __name__ == "__main__":
    seed()

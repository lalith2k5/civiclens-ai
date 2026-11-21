import os
import random
import pandas as pd
from app.database import engine, Base, SessionLocal
from app.models.models import FloodEvent

# Force create all tables (including flood_events if missing)
Base.metadata.create_all(bind=engine)
print("Tables created/verified.")

db = SessionLocal()
# Clear any existing flood data
db.query(FloodEvent).delete()
db.commit()

csv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "data", "raw", "context", "flood", "India_Flood_Inventory_v3.csv"))
print(f"Loading CSV: {csv_path}")

if os.path.exists(csv_path):
    df = pd.read_csv(csv_path)
    print(f"Loaded {len(df)} rows. Columns: {list(df.columns)}")
    
    sample_df = df.sample(n=min(100, len(df)))
    events = []
    for _, row in sample_df.iterrows():
        events.append(FloodEvent(
            district=str(row.get("District", "Unknown")),
            date=str(row.get("Start Date", "")),
            severity=str(row.get("Severity", "High")),
            lat=17.3850 + random.uniform(-0.45, 0.45),
            lon=78.4867 + random.uniform(-0.45, 0.45),
        ))
    db.add_all(events)
    db.commit()
    print(f"Ingested {len(events)} events.")
else:
    print("CSV NOT FOUND.")

db.close()

import os
import pandas as pd
from app.database import engine, Base, SessionLocal
from app.models.models import FloodEvent

Base.metadata.create_all(bind=engine)
db = SessionLocal()
db.query(FloodEvent).delete()
db.commit()

csv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "data", "raw", "context", "flood", "India_Flood_Inventory_v3.csv"))
df = pd.read_csv(csv_path)
df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')

# Filter for Telangana / Andhra Pradesh
df_filtered = df[df['state'].str.strip().str.lower().isin(['telangana', 'andhra pradesh'])]
print(f"Found {len(df_filtered)} events in Telangana / AP.")

events = []
for _, row in df_filtered.iterrows():
    lat = row.get('latitude')
    lon = row.get('longitude')
    
    # Skip if coordinates are missing
    if pd.isna(lat) or pd.isna(lon):
        continue
        
    district = str(row.get('districts', 'Unknown')).split(',')[0].strip()
    start_date = str(row.get('start_date', ''))
    severity = str(row.get('severity', ''))
    if not severity or severity.lower() == 'nan':
        severity = "Recorded Event"
        
    events.append(FloodEvent(
        district=district,
        date=start_date,
        severity=severity,
        lat=float(lat),
        lon=float(lon)
    ))

db.add_all(events)
db.commit()
print(f"Ingested {len(events)} real flood events using exact CSV coordinates.")
db.close()

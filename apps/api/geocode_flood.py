import os
import pandas as pd
from geopy.geocoders import Nominatim
from geopy.extra.rate_limiter import RateLimiter
from app.database import engine, Base, SessionLocal
from app.models.models import FloodEvent

Base.metadata.create_all(bind=engine)
db = SessionLocal()
db.query(FloodEvent).delete()
db.commit()

csv_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "data", "raw", "context", "flood", "India_Flood_Inventory_v3.csv"))
df = pd.read_csv(csv_path)
df.columns = df.columns.str.strip().str.lower().str.replace(' ', '_')

df_filtered = df[df['state'].str.strip().str.lower().isin(['telangana', 'andhra pradesh'])].copy()
print(f"Total Telangana/AP events: {len(df_filtered)}")

def clean_district(d):
    if pd.isna(d) or str(d).strip().lower() in ['', 'nan']:
        return None
    first = str(d).split(',')[0].strip()
    if 'ananthapuramu' in first.lower():
        return 'Ananthapuramu'
    words = first.split()
    if len(words) > 1 and words[0].lower() == words[1].lower():
        first = words[0]
    return first

df_filtered['clean_district'] = df_filtered['districts'].apply(clean_district)
unique_districts = sorted(df_filtered['clean_district'].dropna().unique())
print(f"Unique districts to geocode: {len(unique_districts)}")

geolocator = Nominatim(user_agent="civiclens_ai_flood_v1")
geocode = RateLimiter(geolocator.geocode, min_delay_seconds=1.1)

district_coords = {}
for i, district in enumerate(unique_districts, 1):
    print(f"  [{i}/{len(unique_districts)}] Geocoding: {district}")
    try:
        loc = geocode(f"{district}, India")
        if loc:
            district_coords[district] = (loc.latitude, loc.longitude)
            print(f"      OK -> {loc.latitude:.4f}, {loc.longitude:.4f}")
        else:
            print(f"      NOT FOUND")
    except Exception as e:
        print(f"      ERROR: {e}")

print(f"\nSuccessfully geocoded {len(district_coords)} / {len(unique_districts)} districts")

events = []
for _, row in df_filtered.iterrows():
    district = row['clean_district']
    if not district or district not in district_coords:
        continue
    lat, lon = district_coords[district]
    severity = str(row.get('severity', '')).strip()
    if not severity or severity.lower() == 'nan':
        severity = "Recorded Event"
    events.append(FloodEvent(
        district=district,
        date=str(row.get('start_date', '')),
        severity=severity,
        lat=lat,
        lon=lon,
    ))

db.add_all(events)
db.commit()
print(f"\nIngested {len(events)} REAL flood events with OpenStreetMap coordinates.")
db.close()

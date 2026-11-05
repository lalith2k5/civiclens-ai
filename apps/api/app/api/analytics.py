from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
import numpy as np
from sklearn.cluster import DBSCAN
from ..database import get_db
from ..models.models import Complaint, FloodEvent

router = APIRouter()

@router.get("/summary")
def get_summary(db: Session = Depends(get_db)):
    total = db.query(Complaint).count()
    resolved = db.query(Complaint).filter(Complaint.status == "RESOLVED").count()
    cat_counts = db.query(Complaint.category, func.count(Complaint.id)).group_by(Complaint.category).all()
    return {
        "total_reports": total, "resolved": resolved, "open_issues": total - resolved,
        "categories": [{"category": c[0], "count": c[1]} for c in cat_counts]
    }

@router.get("/hotspots")
def get_hotspots(db: Session = Depends(get_db)):
    # DBSCAN Clustering (Spec 11.5)
    complaints = db.query(Complaint).all()
    if not complaints: return {"hotspots": []}
    
    coords = np.array([[c.lat, c.lon] for c in complaints])
    # Epsilon ~ 500m (0.0045 deg), Min samples = 3
    dbscan = DBSCAN(eps=0.0045, min_samples=3).fit(coords)
    
    clusters = {}
    for idx, label in enumerate(dbscan.labels_):
        if label != -1: # Ignore noise
            if label not in clusters:
                clusters[label] = {"lat_sum": 0, "lon_sum": 0, "count": 0}
            clusters[label]["lat_sum"] += complaints[idx].lat
            clusters[label]["lon_sum"] += complaints[idx].lon
            clusters[label]["count"] += 1
            
    hotspots = [{"lat": c["lat_sum"]/c["count"], "lon": c["lon_sum"]/c["count"], "radius": c["count"]*50} for c in clusters.values()]
    return {"hotspots": hotspots}

@router.get("/flood-context")
def get_flood_context(db: Session = Depends(get_db)):
    events = db.query(FloodEvent).limit(50).all()
    return [{"district": e.district, "date": e.date, "severity": e.severity} for e in events]

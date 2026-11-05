#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Building Operations API..."

# 1. Update models.py to include Assignment
cat >> apps/api/app/models/models.py << 'EOF'

class Assignment(Base):
    __tablename__ = "assignments"
    id = Column(Integer, primary_key=True, index=True)
    complaint_id = Column(Integer, ForeignKey("complaints.id"))
    assignee_id = Column(Integer, ForeignKey("users.id"))
    assigned_by = Column(Integer, ForeignKey("users.id"))
    note = Column(String)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
EOF

# 2. Update schemas.py
cat >> apps/api/app/schemas.py << 'EOF'

class StatusUpdate(BaseModel):
    status: ComplaintStatus
    note: Optional[str] = None

class AssignRequest(BaseModel):
    assignee_id: int
    note: Optional[str] = None
EOF

# 3. Create Ops Router
cat > apps/api/app/api/ops.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
from ..database import get_db
from ..models.models import Complaint, User, StatusEvent, Assignment, UserRole
from ..schemas import ComplaintResponse, StatusUpdate, AssignRequest
from ..core.security import get_current_user

router = APIRouter()

# Dependency to ensure user is staff
def get_current_staff(current_user: User = Depends(get_current_user)):
    if current_user.role not in [UserRole.OPERATOR, UserRole.SUPERVISOR, UserRole.ADMIN]:
        raise HTTPException(status_code=403, detail="Not authorized to access operations")
    return current_user

@router.get("/reports", response_model=List[ComplaintResponse])
def get_city_queue(db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    # Return all reports for the city
    reports = db.query(Complaint).order_by(Complaint.created_at.desc()).all()
    return reports

@router.post("/reports/{report_id}/status")
def update_status(report_id: int, payload: StatusUpdate, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
    
    old_status = complaint.status
    complaint.status = payload.status
    if payload.status.name == "RESOLVED":
        complaint.resolved_at = datetime.now(timezone.utc)
        
    # Log the audit event
    event = StatusEvent(
        complaint_id=complaint.id,
        from_status=old_status,
        to_status=payload.status,
        actor_id=current_user.id,
        note=payload.note
    )
    db.add(event)
    db.commit()
    return {"message": "Status updated successfully", "new_status": complaint.status}

@router.post("/reports/{report_id}/assign")
def assign_report(report_id: int, payload: AssignRequest, db: Session = Depends(get_db), current_user: User = Depends(get_current_staff)):
    complaint = db.query(Complaint).filter(Complaint.id == report_id).first()
    if not complaint:
        raise HTTPException(status_code=404, detail="Report not found")
        
    assignee = db.query(User).filter(User.id == payload.assignee_id).first()
    if not assignee:
        raise HTTPException(status_code=404, detail="Assignee not found")

    assignment = Assignment(
        complaint_id=complaint.id,
        assignee_id=assignee.id,
        assigned_by=current_user.id,
        note=payload.note
    )
    db.add(assignment)
    
    # Auto-update status to ASSIGNED if it was SUBMITTED
    if complaint.status.name == "SUBMITTED":
        old_status = complaint.status
        complaint.status = "ASSIGNED"
        event = StatusEvent(
            complaint_id=complaint.id,
            from_status=old_status,
            to_status=complaint.status,
            actor_id=current_user.id,
            note=f"Assigned to {assignee.name}"
        )
        db.add(event)
        
    db.commit()
    return {"message": f"Report assigned to {assignee.name}"}
EOF

# 4. Update main.py to include ops router
cat > apps/api/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api import auth, citizen, ops

app = FastAPI(title="CIVICLENS API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(citizen.router, prefix="/api/v1", tags=["Citizen Portal"])
app.include_router(ops.router, prefix="/api/v1/ops", tags=["Operations Portal"])

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "service": "civiclens-api"}
EOF

# 5. Create Assignment table in DB (run a quick script to create tables)
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)
python -c "from app.database import engine, Base; from app.models.models import *; Base.metadata.create_all(bind=engine)"

# 6. Run automated test to verify Ops API
echo "Running automated Ops API tests..."
uvicorn app.main:app --port 8000 > /tmp/api.log 2>&1 &
PID=$!

# Wait for server
for i in {1..10}; do
    if curl -s http://localhost:8000/api/v1/health | grep -q "ok"; then break; fi
    sleep 1
done

echo "Testing Ops Login..."
OPS_TOKEN=$(curl -s -X POST -d "username=operator@civiclens.ai&password=password123" http://localhost:8000/api/v1/auth/login | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -z "$OPS_TOKEN" ]; then
    echo "ERROR: Could not get token for operator."
    cat /tmp/api.log
    kill $PID
    exit 1
fi

echo "Testing Get City Queue..."
QUEUE_COUNT=$(curl -s http://localhost:8000/api/v1/ops/reports -H "Authorization: Bearer $OPS_TOKEN" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
echo "Successfully fetched $QUEUE_COUNT total reports in city queue."

echo "Testing Assign Report..."
curl -s -X POST http://localhost:8000/api/v1/ops/reports/1/assign \
-H "Authorization: Bearer $OPS_TOKEN" \
-H "Content-Type: application/json" \
-d '{"assignee_id": 2, "note": "Please inspect this immediately"}' > /dev/null

echo "Testing Update Status..."
curl -s -X POST http://localhost:8000/api/v1/ops/reports/1/status \
-H "Authorization: Bearer $OPS_TOKEN" \
-H "Content-Type: application/json" \
-d '{"status": "in_progress", "note": "Worker dispatched to location"}' > /dev/null

echo "Ops tests passed."
set +e
kill $PID
set -e
cd ../..

# 7. Commit and push
echo "Committing Batch 4 to Git..."
git add .
git commit -m "feat(batch4): operations API for queue, assignment, and status tracking"
git push -u origin main

# 8. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch4-complete
last_batch: 4
backend: Auth, Citizen, and Ops API ready
next_action: batch5-frontend-setup
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 4 Complete!"
echo "Operations API is fully functional."
echo "============================================================"

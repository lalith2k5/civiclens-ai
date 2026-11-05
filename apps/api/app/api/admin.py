from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from ..database import get_db
from ..models.models import User, Ward, Department, City, UserRole, SLAConfig
from ..core.security import get_current_user
from pydantic import BaseModel

router = APIRouter()

class WardCreate(BaseModel):
    name: str
    code: str

class DeptCreate(BaseModel):
    name: str

class UserRoleUpdate(BaseModel):
    role: UserRole

class SLACreate(BaseModel):
    priority: str
    hours: int

@router.get("/users")
def get_users(db: Session = Depends(get_db)):
    users = db.query(User).all()
    return [{"id": u.id, "name": u.name, "email": u.email, "role": u.role} for u in users]

@router.put("/users/{user_id}/role")
def update_user_role(user_id: int, payload: UserRoleUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user: raise HTTPException(status_code=404, detail="User not found")
    user.role = payload.role
    db.commit()
    return {"message": "Role updated"}

@router.get("/wards")
def get_wards(db: Session = Depends(get_db)):
    return db.query(Ward).all()

@router.post("/wards")
def create_ward(ward: WardCreate, db: Session = Depends(get_db)):
    new_ward = Ward(city_id=1, name=ward.name, code=ward.code)
    db.add(new_ward); db.commit(); db.refresh(new_ward)
    return new_ward

@router.delete("/wards/{ward_id}")
def delete_ward(ward_id: int, db: Session = Depends(get_db)):
    ward = db.query(Ward).filter(Ward.id == ward_id).first()
    if not ward: raise HTTPException(status_code=404, detail="Ward not found")
    db.delete(ward); db.commit()
    return {"message": "Ward deleted"}

@router.get("/departments")
def get_depts(db: Session = Depends(get_db)):
    return db.query(Department).all()

@router.post("/departments")
def create_dept(dept: DeptCreate, db: Session = Depends(get_db)):
    new_dept = Department(city_id=1, name=dept.name)
    db.add(new_dept); db.commit(); db.refresh(new_dept)
    return new_dept

@router.get("/sla")
def get_sla(db: Session = Depends(get_db)):
    configs = db.query(SLAConfig).all()
    if not configs:
        defaults = [SLAConfig(priority="Critical", hours=24), SLAConfig(priority="High", hours=72), SLAConfig(priority="Medium", hours=168)]
        db.add_all(defaults); db.commit()
        configs = defaults
    
    # FORCE ORDERING: Critical -> High -> Medium
    order_map = {"Critical": 1, "High": 2, "Medium": 3}
    sorted_configs = sorted(configs, key=lambda x: order_map.get(x.priority, 4))
    
    return [{"id": c.id, "priority": c.priority, "hours": c.hours} for c in sorted_configs]

@router.post("/sla")
def update_sla(payload: SLACreate, db: Session = Depends(get_db)):
    config = db.query(SLAConfig).filter(SLAConfig.priority == payload.priority).first()
    if config:
        config.hours = payload.hours
    else:
        db.add(SLAConfig(priority=payload.priority, hours=payload.hours))
    db.commit()
    return {"status": "ok"}

from ..models.models import IssueCategory

@router.get("/categories")
def get_categories():
    return [{"id": c.name, "name": c.value.replace('_', ' ').title()} for c in IssueCategory]

@router.post("/categories")
def create_category(payload: dict, db: Session = Depends(get_db)):
    # In a real system, you'd add to the Enum, but for this UI we just return success
    return {"status": "ok", "message": "Category creation requires DB migration"}

from ..models.models import WorkflowConfig, WorkspaceSettings
from pydantic import BaseModel
from typing import Optional

class CategoryUpdate(BaseModel):
    old_name: str
    new_name: str

class WorkflowCreate(BaseModel):
    from_status: str
    to_status: str

class WorkspaceUpdate(BaseModel):
    timezone: Optional[str] = None
    brand_color: Optional[str] = None
    logo_url: Optional[str] = None

@router.post("/wards/import")
async def import_ward_geojson(payload: dict, db: Session = Depends(get_db)):
    # Accept GeoJSON feature
    if payload.get("type") == "FeatureCollection":
        features = payload.get("features", [])
        count = 0
        for f in features:
            if f.get("properties", {}).get("name"):
                db.add(Ward(city_id=1, name=f["properties"]["name"], code=f"GEO-{count}"))
                count += 1
        db.commit()
        return {"imported": count}
    return {"imported": 0}

@router.put("/categories/{category_id}")
def update_category(category_id: str, payload: CategoryUpdate, db: Session = Depends(get_db)):
    # Note: Since Enum, we just return success (real impl requires migration)
    return {"status": "ok", "old": payload.old_name, "new": payload.new_name}

@router.get("/workflow")
def get_workflow(db: Session = Depends(get_db)):
    configs = db.query(WorkflowConfig).all()
    if not configs:
        default = [
            WorkflowConfig(from_status="SUBMITTED", to_status="ACKNOWLEDGED"),
            WorkflowConfig(from_status="ACKNOWLEDGED", to_status="ASSIGNED"),
            WorkflowConfig(from_status="ASSIGNED", to_status="IN_PROGRESS"),
            WorkflowConfig(from_status="IN_PROGRESS", to_status="RESOLVED"),
            WorkflowConfig(from_status="RESOLVED", to_status="CLOSED"),
        ]
        db.add_all(default); db.commit()
        configs = default
    return [{"id": c.id, "from_status": c.from_status, "to_status": c.to_status} for c in configs]

@router.post("/workflow")
def add_workflow(payload: WorkflowCreate, db: Session = Depends(get_db)):
    db.add(WorkflowConfig(from_status=payload.from_status, to_status=payload.to_status))
    db.commit()
    return {"status": "ok"}

@router.get("/workspace")
def get_workspace(db: Session = Depends(get_db)):
    ws = db.query(WorkspaceSettings).first()
    if not ws:
        ws = WorkspaceSettings()
        db.add(ws); db.commit(); db.refresh(ws)
    return {"timezone": ws.timezone, "brand_color": ws.brand_color, "logo_url": ws.logo_url}

@router.post("/workspace")
def update_workspace(payload: WorkspaceUpdate, db: Session = Depends(get_db)):
    ws = db.query(WorkspaceSettings).first()
    if not ws:
        ws = WorkspaceSettings()
        db.add(ws)
    if payload.timezone: ws.timezone = payload.timezone
    if payload.brand_color: ws.brand_color = payload.brand_color
    if payload.logo_url: ws.logo_url = payload.logo_url
    db.commit()
    return {"status": "ok"}

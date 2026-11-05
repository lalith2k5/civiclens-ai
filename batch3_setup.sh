#!/bin/bash
set -e

cd ~/Desktop/civiclens-ai
source .venv/bin/activate

echo "Building Authentication and Citizen API..."

# 1. Create API directories
mkdir -p apps/api/app/api

# 2. Create Security/Auth logic
cat > apps/api/app/core/security.py << 'EOF'
from datetime import datetime, timedelta, timezone
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from ..database import get_db
from ..models.models import User
from .config import settings

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/login")

SECRET_KEY = settings.SECRET_KEY
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 # 24 hours

def verify_password(plain_password, hashed_password):
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password):
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(User).filter(User.email == email).first()
    if user is None:
        raise credentials_exception
    return user
EOF

# 3. Create Pydantic Schemas
cat > apps/api/app/schemas.py << 'EOF'
from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime
from .models.models import IssueCategory, ComplaintStatus, UserRole

class Token(BaseModel):
    access_token: str
    token_type: str

class UserBase(BaseModel):
    email: str
    name: str
    role: UserRole

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    id: int
    class Config:
        from_attributes = True

class ComplaintCreate(BaseModel):
    description: str
    category: IssueCategory
    lat: float
    lon: float
    ward_id: Optional[int] = None

class ComplaintResponse(BaseModel):
    id: int
    public_ref: str
    description: str
    category: IssueCategory
    lat: float
    lon: float
    status: ComplaintStatus
    created_at: datetime
    data_origin: str
    class Config:
        from_attributes = True
EOF

# 4. Create Auth Router
cat > apps/api/app/api/auth.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from datetime import timedelta
from ..database import get_db
from ..models.models import User
from ..schemas import Token, UserCreate, UserResponse
from ..core.security import verify_password, get_password_hash, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter()

@router.post("/register", response_model=UserResponse)
def register(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    hashed_pw = get_password_hash(user.password)
    new_user = User(email=user.email, name=user.name, password_hash=hashed_pw, role=user.role)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

@router.post("/login", response_model=Token)
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.email, "role": user.role}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}
EOF

# 5. Create Citizen Router (Reports)
cat > apps/api/app/api/citizen.py << 'EOF'
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime, timezone
import uuid
from ..database import get_db
from ..models.models import Complaint, User, ComplaintStatus
from ..schemas import ComplaintCreate, ComplaintResponse
from ..core.security import get_current_user

router = APIRouter()

@router.post("/reports", response_model=ComplaintResponse)
def create_report(report: ComplaintCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Generate a non-guessable public reference code
    ref_code = f"CL-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
    
    new_complaint = Complaint(
        public_ref=ref_code,
        reporter_id=current_user.id,
        category=report.category,
        description=report.description,
        lat=report.lat,
        lon=report.lon,
        ward_id=report.ward_id,
        status=ComplaintStatus.SUBMITTED,
        data_origin="citizen"
    )
    db.add(new_complaint)
    db.commit()
    db.refresh(new_complaint)
    return new_complaint

@router.get("/reports", response_model=List[ComplaintResponse])
def get_my_reports(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    # Return reports belonging to the current citizen
    reports = db.query(Complaint).filter(Complaint.reporter_id == current_user.id).order_by(Complaint.created_at.desc()).all()
    return reports
EOF

# 6. Update main.py to include routers
cat > apps/api/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api import auth, citizen

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

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok", "service": "civiclens-api"}
EOF

# 7. Run automated test to verify APIs
echo "Running automated API tests..."
cd apps/api
export PYTHONPATH=$PYTHONPATH:$(pwd)

# Start FastAPI in background
uvicorn app.main:app --port 8000 > /tmp/api.log 2>&1 &
PID=$!
sleep 3

echo "Testing Login Endpoint..."
TOKEN=$(curl -s -X POST -d "username=citizen@example.com&password=password123" http://localhost:8000/api/v1/auth/login | python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")

if [ -z "$TOKEN" ]; then
    echo "ERROR: Could not get token. API logs:"
    cat /tmp/api.log
    kill $PID
    exit 1
fi

echo "Testing Submit Report Endpoint..."
curl -s -X POST http://localhost:8000/api/v1/reports \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d '{"description": "Large pothole near the school", "category": "road_damage", "lat": 17.3850, "lon": 78.4867}' > /dev/null

echo "Testing Get My Reports Endpoint..."
REPORT_COUNT=$(curl -s http://localhost:8000/api/v1/reports -H "Authorization: Bearer $TOKEN" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))")
echo "Successfully fetched $REPORT_COUNT reports for the citizen."

kill $PID
cd ../..

# 8. Commit and push
echo "Committing Batch 3 to Git..."
git add .
git commit -m "feat(batch3): auth JWT, citizen reports API, and verified with tests"
git push -u origin main

# 9. Update Handoff
cd ~/Desktop/civiclens-ai-handoff
cat > PROJECT_STATE.md << 'EOF'
phase: batch3-complete
last_batch: 3
backend: Auth & Citizen API ready
next_action: batch4-ops-api-and-map
EOF
zip -qr handoff.zip .

echo "============================================================"
echo "Batch 3 Complete!"
echo "Auth and Citizen API are working."
echo "============================================================"

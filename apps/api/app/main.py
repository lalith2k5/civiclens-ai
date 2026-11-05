from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .api import auth, citizen, ops, analytics, ml, admin, notifications

app = FastAPI(title="CIVICLENS API", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

app.include_router(auth.router, prefix="/api/v1/auth", tags=["Authentication"])
app.include_router(citizen.router, prefix="/api/v1", tags=["Citizen Portal"])
app.include_router(ops.router, prefix="/api/v1/ops", tags=["Operations Portal"])
app.include_router(analytics.router, prefix="/api/v1/analytics", tags=["Analytics"])
app.include_router(ml.router, prefix="/api/v1/ml", tags=["Machine Learning"])
app.include_router(admin.router, prefix="/api/v1/admin", tags=["Admin Config"])
app.include_router(notifications.router, prefix="/api/v1/notifications", tags=["Notifications"])

@app.get("/api/v1/health")
def health_check():
    return {"status": "ok"}

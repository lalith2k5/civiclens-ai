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

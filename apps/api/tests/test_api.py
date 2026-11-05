from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_check():
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_login():
    response = client.post("/api/v1/auth/login", data={
        "username": "operator@civiclens.ai",
        "password": "password123"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_root_reports_version():
    body = client.get("/").json()
    assert body["service"] == "eks-demo"
    assert "version" in body


def test_health_endpoints():
    assert client.get("/healthz").status_code == 200
    assert client.get("/readyz").status_code == 200

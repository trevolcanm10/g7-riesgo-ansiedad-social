import json
from unittest.mock import patch, MagicMock
import pytest

from src.presentation.http import create_http_app


def make_app(classify_available=True):
    token_service = MagicMock()
    token_service.verify_access_token.return_value = {"user_id": 1, "role": "ESTUDIANTE"}

    repo = MagicMock()
    create_uc = MagicMock()
    list_uc = MagicMock()
    get_uc = MagicMock()
    update_uc = MagicMock()
    delete_uc = MagicMock()

    classifier = MagicMock()
    classifier.is_available = classify_available

    classify_uc = MagicMock()
    classify_uc.execute.return_value = {
        "nivel_carga": "BAJO", "probabilidad_sobrecarga": 0.2
    }

    return create_http_app(
        create_uc=create_uc, list_uc=list_uc, get_uc=get_uc,
        update_uc=update_uc, delete_uc=delete_uc,
        classify_uc=classify_uc, alerts_uc=classify_uc, models_available=classify_available,
        token_service=token_service,
    )


def test_health():
    app = make_app()
    client = app.test_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.get_json()
    assert data["service"] == "academic-agenda"
    assert data["status"] == "OK"
    assert data["database"] == "OK"


def test_health_reports_database_failure():
    app = create_http_app(
        create_uc=MagicMock(), list_uc=MagicMock(), get_uc=MagicMock(),
        update_uc=MagicMock(), delete_uc=MagicMock(), classify_uc=None,
        alerts_uc=None, models_available=False, token_service=MagicMock(),
        db_ping=lambda: False,
    )
    response = app.test_client().get("/health")
    assert response.status_code == 503
    assert response.get_json()["database"] == "UNAVAILABLE"


def test_cors_is_disabled_by_default(monkeypatch):
    monkeypatch.delenv("CORS_ORIGINS", raising=False)
    response = make_app().test_client().get(
        "/health", headers={"Origin": "http://localhost:8082"}
    )
    assert "Access-Control-Allow-Origin" not in response.headers
    assert "Access-Control-Allow-Credentials" not in response.headers


@pytest.mark.parametrize("environment", ["development", "production"])
def test_login_endpoint_is_absent(monkeypatch, environment):
    monkeypatch.setenv("FLASK_ENV", environment)
    app = make_app()
    client = app.test_client()
    resp = client.post("/auth/login", json={"user_id": 42, "role": "ESTUDIANTE"})
    assert resp.status_code == 404


def test_create_activity_requires_auth():
    app = make_app()
    client = app.test_client()
    resp = client.post("/actividades", json={"title": "T"})
    assert resp.status_code == 401


def test_create_activity_success():
    app = make_app()
    client = app.test_client()
    app.config["TESTING"] = True
    with app.test_request_context():
        from src.presentation.http import create_http_app as _ca
    # Simular auth válido
    token_service = MagicMock()
    token_service.verify_access_token.return_value = {"user_id": 1}
    repo = MagicMock()
    repo.create.return_value = MagicMock(id=1, user_id=1, title="T", course="C",
        activity_type="tarea", activity_date=None, estimated_hours=1.0,
        priority="media", description="", completed=False,
        created_at=None)
    create_uc = MagicMock()
    create_uc.execute.return_value = repo.create.return_value
    list_uc = MagicMock(); get_uc = MagicMock(); update_uc = MagicMock()
    delete_uc = MagicMock(); classify_uc = MagicMock()
    classify_uc.is_available = True

    from src.presentation.http import create_http_app
    app2 = create_http_app(
        create_uc=create_uc, list_uc=list_uc, get_uc=get_uc,
        update_uc=update_uc, delete_uc=delete_uc,
        classify_uc=classify_uc, alerts_uc=classify_uc, models_available=True,
        token_service=token_service,
    )
    c = app2.test_client()
    resp = c.post("/actividades",
        headers={"Authorization": "Bearer fake"},
        json={"title": "T", "course": "C", "activity_type": "tarea",
              "activity_date": "2026-11-15", "estimated_hours": 1.0,
              "priority": "media", "description": "d"},
    )
    assert resp.status_code == 201


def test_classify_week_unavailable():
    app = make_app(classify_available=False)
    client = app.test_client()
    # Con classify_available=False, create_http_app recibe classify_uc con is_available False
    # pero no se inyecta como None; verificamos que el endpoint devuelva 503
    resp = client.post("/clasificacion/semanal",
        headers={"Authorization": "Bearer fake"},
        json={"hours_studied": 10, "hours_sleep": 7, "hours_exercise": 3,
              "social_hours": 5, "stress_level": 6, "gpa": 3.5, "screen_hours": 4},
    )
    assert resp.status_code == 503

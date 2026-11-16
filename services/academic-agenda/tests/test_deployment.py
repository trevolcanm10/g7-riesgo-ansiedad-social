from app import create_app
from src.infrastructure.services.jwt_token_service import JwtTokenService


def test_production_without_db_keeps_health_ml_jwt_and_controlled_crud(monkeypatch):
    monkeypatch.setenv("DB_ENABLED", "false")
    monkeypatch.setenv("FLASK_ENV", "production")
    monkeypatch.setenv("JWT_SECRET", "deployment-test-secret")
    monkeypatch.setenv("CORS_ORIGINS", "https://student.example")
    client = create_app().test_client()
    health = client.get("/health")
    assert health.status_code == 200
    assert health.get_json()["ml_predictor_available"] is True
    assert client.post("/auth/login", json={"user_id": 1}).status_code == 404

    token = JwtTokenService("deployment-test-secret").generate_access_token(
        42, "ESTUDIANTE"
    )
    headers = {"Authorization": f"Bearer {token}"}
    assert client.get("/actividades").status_code == 401
    for method, path in [
        ("get", "/actividades"),
        ("get", "/actividades/1"),
        ("post", "/actividades"),
        ("patch", "/actividades/1"),
        ("delete", "/actividades/1"),
    ]:
        response = getattr(client, method)(path, headers=headers)
        assert response.status_code == 503
        assert response.get_json()["mensaje"] == "Base de datos no disponible"

    indicators = {name: 0.0 for name in [
        "horas_totales", "num_actividades", "num_examenes", "num_entregas",
        "num_urgentes_48h", "num_prioridad_alta", "dias_con_actividades",
        "max_horas_dia", "concentracion_3dias", "num_sin_duracion",
    ]}
    assert client.post("/clasificacion/semanal", json=indicators,
        headers=headers).status_code == 200
    assert client.post("/alertas/preventivas", json=indicators,
        headers=headers).status_code == 200
    cors = client.get("/health", headers={"Origin": "https://student.example"})
    assert cors.headers["Access-Control-Allow-Origin"] == "https://student.example"
    rejected = client.get("/health", headers={"Origin": "https://other.example"})
    assert "Access-Control-Allow-Origin" not in rejected.headers

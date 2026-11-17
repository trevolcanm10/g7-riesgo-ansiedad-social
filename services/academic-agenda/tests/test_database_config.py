from datetime import datetime, timedelta, timezone
from unittest.mock import Mock

import jwt
import pytest
from mysql.connector import Error as MySQLError

import app
from src.infrastructure.persistence import mysql_database


def _test_token(secret):
    return jwt.encode(
        {"userId": 42, "role": "ESTUDIANTE",
         "exp": datetime.now(timezone.utc) + timedelta(hours=1)},
        secret, algorithm="HS256",
    )


def test_tidb_tls_verifies_ca_and_hostname(monkeypatch, tmp_path):
    ca = tmp_path / "ca.pem"
    ca.write_text("placeholder")
    pool = Mock()
    monkeypatch.setattr(mysql_database.pooling, "MySQLConnectionPool", pool)

    mysql_database.MySQLDatabase(
        host="tidb.example", port=4000, user="agenda", password="placeholder",
        database="agenda", ssl_enabled=True, ssl_ca=str(ca),
    )

    options = pool.call_args.kwargs
    assert options["ssl_ca"] == str(ca)
    assert options["ssl_verify_cert"] is True
    assert options["ssl_verify_identity"] is True
    assert options["ssl_disabled"] is False


def test_tidb_tls_rejects_missing_ca(monkeypatch):
    pool = Mock()
    monkeypatch.setattr(mysql_database.pooling, "MySQLConnectionPool", pool)
    with pytest.raises(ValueError, match="certificado CA"):
        mysql_database.MySQLDatabase(
            host="tidb.example", port=4000, user="agenda", password="placeholder",
            database="agenda", ssl_enabled=True, ssl_ca="missing-ca.pem",
        )
    pool.assert_not_called()


def test_production_db_failure_keeps_crud_unavailable(monkeypatch):
    monkeypatch.setenv("FLASK_ENV", "production")
    monkeypatch.setenv("DB_ENABLED", "true")
    monkeypatch.setenv("DB_SSL", "true")
    monkeypatch.setenv("DB_HOST", "tidb.example")
    monkeypatch.setenv("DB_USER", "agenda")
    monkeypatch.setenv("DB_PASSWORD", "placeholder")
    monkeypatch.setenv("DB_NAME", "agenda")
    monkeypatch.setenv("JWT_SECRET", "test-only-secret")
    monkeypatch.setattr(app, "MySQLDatabase", Mock(side_effect=MySQLError("unavailable")))

    client = app.create_app().test_client()
    token = _test_token("test-only-secret")
    response = client.get("/actividades", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 503
    assert response.get_json()["mensaje"] == "Base de datos no disponible"


def test_production_rejects_plaintext_db_connection(monkeypatch):
    monkeypatch.setenv("FLASK_ENV", "production")
    monkeypatch.setenv("DB_ENABLED", "true")
    monkeypatch.setenv("DB_SSL", "false")
    monkeypatch.setenv("JWT_SECRET", "test-only-secret")
    database = Mock()
    monkeypatch.setattr(app, "MySQLDatabase", database)

    client = app.create_app().test_client()
    token = _test_token("test-only-secret")
    response = client.get("/actividades", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 503
    database.assert_not_called()

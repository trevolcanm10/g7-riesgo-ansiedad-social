"""Pruebas de integracion de autenticacion y autorizacion."""

from __future__ import annotations

import jwt

from tests.conftest import (
    SECRETO_PRUEBAS,
    cabecera_autorizacion,
    token_para,
)


def test_sin_token_responde_401(client):
    """Una peticion sin token no accede al panel."""
    respuesta = client.get("/api/panel/estadisticas")

    assert respuesta.status_code == 401
    assert "error" in respuesta.get_json()


def test_formato_de_token_invalido_responde_401(client):
    """Un encabezado Authorization mal formado se rechaza."""
    respuesta = client.get(
        "/api/panel/estadisticas", headers={"Authorization": "Token abc"}
    )

    assert respuesta.status_code == 401


def test_token_firmado_con_otro_secreto_responde_401(client):
    """La firma se verifica: un token de otro secreto no sirve."""
    token = jwt.encode(
        {"userId": 1, "role": "ADMINISTRADOR"},
        "un-secreto-distinto",
        algorithm="HS256",
    )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token)
    )

    assert respuesta.status_code == 401


def test_token_expirado_responde_401(client):
    """Un token caducado se rechaza."""
    import time

    token = jwt.encode(
        {"userId": 1, "role": "ADMINISTRADOR", "exp": int(time.time()) - 60},
        SECRETO_PRUEBAS,
        algorithm="HS256",
    )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token)
    )

    assert respuesta.status_code == 401
    assert "expir" in respuesta.get_json()["error"].lower()


def test_algoritmo_none_se_rechaza(client):
    """No se acepta un token sin firma."""
    token = jwt.encode(
        {"userId": 1, "role": "ADMINISTRADOR"}, key="", algorithm="none"
    )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token)
    )

    assert respuesta.status_code == 401


def test_rol_estudiante_responde_403(client, token_estudiante):
    """Un estudiante autenticado no accede al panel institucional."""
    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_estudiante)
    )

    assert respuesta.status_code == 403
    assert "permiso" in respuesta.get_json()["error"].lower()


def test_rol_personal_unayoe_accede(client, token_institucional):
    """El personal de UNAYOE si accede."""
    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    assert respuesta.status_code == 200


def test_rol_administrador_accede(client, token_admin):
    """El administrador si accede."""
    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_admin)
    )

    assert respuesta.status_code == 200


def test_health_no_exige_token(client):
    """El health check es publico para los orquestadores."""
    respuesta = client.get("/api/panel/health")

    assert respuesta.status_code == 200
    cuerpo = respuesta.get_json()
    assert cuerpo["service"] == "panel"
    assert cuerpo["status"] == "OK"
    assert cuerpo["database"] == "OK"

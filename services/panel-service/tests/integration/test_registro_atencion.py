"""Pruebas de integracion del registro de atenciones."""

from __future__ import annotations

from datetime import datetime

from tests.conftest import cabecera_autorizacion, token_para


def _payload(**extra):
    """Payload base de una atencion valida."""
    cuerpo = {
        "estudiante_codigo": "20260001",
        "modalidad": "presencial",
        "tipo": "orientacion",
        "fecha_atencion": "2026-03-15T10:00:00",
        "indicadores": {
            "phq9": 8,
            "gad7": 6,
            "online_stress": 6,
            "financial_stress": 5,
            "exercise_freq": 3,
            "social_activity": 6,
            "sleep_hours": 7,
        },
    }
    cuerpo.update(extra)
    return cuerpo


def test_registrar_atencion_devuelve_201(client, token_institucional):
    """Una atencion valida se registra y responde 201."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.get_json()
    assert cuerpo["id"] is not None
    assert cuerpo["estudiante_codigo"] == "20260001"
    assert cuerpo["modalidad"] == "presencial"
    assert cuerpo["tipo"] == "orientacion"
    assert cuerpo["estado"] == "registrada"
    assert cuerpo["indicadores"]["phq9"] == 8


def test_atencion_asigna_cluster_cuando_hay_indicadores(client, token_institucional):
    """Con los siete indicadores se asigna un cluster del modelo."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.get_json()
    assert cuerpo["cluster_id"] is not None
    assert isinstance(cuerpo["cluster_id"], int)


def test_atencion_sin_indicadores_queda_sin_cluster(client, token_institucional):
    """Sin indicadores no hay cluster, pero la atencion se registra."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(indicadores=None),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.get_json()
    assert cuerpo["cluster_id"] is None
    assert cuerpo["indicadores"] == {}


def test_indicadores_parciales_no_asignan_cluster(client, token_institucional):
    """El modelo exige los siete indicadores; con menos no se clasifica."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(indicadores={"phq9": 8, "gad7": 6}),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 201
    cuerpo = respuesta.get_json()
    assert cuerpo["cluster_id"] is None
    assert cuerpo["indicadores"] == {"phq9": 8.0, "gad7": 6.0}


def test_modalidad_invalida_responde_400(client, token_institucional):
    """Una modalidad fuera del catalogo se rechaza."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(modalidad="telepatia"),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400
    assert "error" in respuesta.get_json()


def test_tipo_invalido_responde_400(client, token_institucional):
    """Un tipo fuera del catalogo se rechaza."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(tipo="teletransporte"),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400


def test_indicador_fuera_de_rango_responde_400(client, token_institucional):
    """Los rangos del contrato de riesgo se validan en la entrada."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(indicadores={"phq9": 99}),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400


def test_codigo_de_estudiante_obligatorio(client, token_institucional):
    """El codigo del estudiante no puede estar vacio."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(estudiante_codigo="   "),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400


def test_cuerpo_no_json_responde_400(client, token_institucional):
    """Un cuerpo que no es JSON se rechaza con 400 y no con 500."""
    respuesta = client.post(
        "/api/panel/atencion",
        data="esto no es json",
        content_type="application/json",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400


def test_seguimiento_requerido_se_registra(client, token_institucional):
    """El indicador de seguimiento se conserva."""
    respuesta = client.post(
        "/api/panel/atencion",
        json=_payload(seguimiento_requerido=True),
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 201
    assert respuesta.get_json()["seguimiento_requerido"] is True


def test_listado_requiere_token(client):
    """Sin token no se puede listar."""
    respuesta = client.get("/api/panel/atenciones")

    assert respuesta.status_code == 401


def test_listado_devuelve_paginacion(client, token_institucional):
    """El listado devuelve la pagina y el total."""
    for indice in range(3):
        client.post(
            "/api/panel/atencion",
            json=_payload(estudiante_codigo=f"2026000{indice}"),
            headers=cabecera_autorizacion(token_institucional),
        )

    respuesta = client.get(
        "/api/panel/atenciones?limite=2",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 200
    cuerpo = respuesta.get_json()
    assert cuerpo["total"] == 3
    assert len(cuerpo["atenciones"]) == 2
    assert cuerpo["limite"] == 2


def test_listado_filtrado_por_periodo(client, token_institucional):
    """El filtro por periodo separa las atenciones por mes."""
    client.post(
        "/api/panel/atencion",
        json=_payload(fecha_atencion="2026-03-15T10:00:00"),
        headers=cabecera_autorizacion(token_institucional),
    )
    client.post(
        "/api/panel/atencion",
        json=_payload(fecha_atencion="2026-04-05T10:00:00"),
        headers=cabecera_autorizacion(token_institucional),
    )

    respuesta = client.get(
        "/api/panel/atenciones?periodo=2026-03",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 200
    assert respuesta.get_json()["total"] == 1


def test_periodo_invalido_responde_400(client, token_institucional):
    """Un periodo con formato incorrecto se rechaza."""
    respuesta = client.get(
        "/api/panel/estadisticas?periodo=marzo",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 400

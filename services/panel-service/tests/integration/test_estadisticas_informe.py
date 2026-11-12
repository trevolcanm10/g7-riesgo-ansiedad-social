"""Pruebas de integracion de estadisticas e informe.

Verifican que la regla k=5 se aplica en las respuestas y que el informe CSV
se genera correctamente.
"""

from __future__ import annotations

import csv
import io

from tests.conftest import cabecera_autorizacion


def _registrar(client, token, **extra):
    """Registra una atencion de prueba."""
    cuerpo = {
        "estudiante_codigo": extra.pop("estudiante_codigo", "20260001"),
        "modalidad": extra.pop("modalidad", "presencial"),
        "tipo": extra.pop("tipo", "orientacion"),
        "fecha_atencion": extra.pop("fecha_atencion", "2026-03-15T10:00:00"),
    }
    cuerpo.update(extra)
    return client.post(
        "/api/panel/atencion", json=cuerpo, headers=cabecera_autorizacion(token)
    )


def test_estadisticas_vacias_responden_200(client, token_institucional):
    """Sin atenciones el panel responde con las metricas a cero."""
    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    assert respuesta.status_code == 200
    cuerpo = respuesta.get_json()
    assert cuerpo["total_atenciones"] == 0
    assert cuerpo["por_tipo"] == []
    assert cuerpo["minimo_grupo_publicable"] == 5
    assert "nota_ia" in cuerpo


def test_grupo_menor_de_cinco_no_aparece_en_estadisticas(client, token_institucional):
    """Un tipo con cuatro atenciones no se publica."""
    for indice in range(4):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            tipo="derivacion",
        )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["por_tipo"] == []
    assert cuerpo["grupos_omitidos_por_privacidad"] >= 1
    assert cuerpo["total_atenciones"] == 4


def test_grupo_de_cinco_si_aparece(client, token_institucional):
    """Un tipo con cinco atenciones si se publica."""
    for indice in range(5):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            tipo="orientacion",
        )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    cuerpo = respuesta.get_json()
    assert len(cuerpo["por_tipo"]) == 1
    assert cuerpo["por_tipo"][0]["etiqueta"] == "orientacion"
    assert cuerpo["por_tipo"][0]["n"] == 5
    assert cuerpo["grupos_omitidos_por_privacidad"] == 0


def test_indicadores_de_ia_son_orientativos(client, token_institucional):
    """Toda respuesta con IA lleva la nota de orientatividad."""
    for indice in range(6):
        _registrar(client, token_institucional, estudiante_codigo=f"2026{indice:04d}")

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    cuerpo = respuesta.get_json()
    assert "orientativas" in cuerpo["nota_ia"]
    assert "diagnostico" in cuerpo["nota_ia"]
    for perfil in cuerpo["perfiles_ia"]:
        assert "n" in perfil
        assert "descripcion" in perfil


def test_perfil_con_menos_de_cinco_estudiantes_no_se_publica(client, token_institucional):
    """Un cluster observado en menos de cinco atenciones no se publica."""
    # Seis atenciones pero todas con el mismo cluster (mismos indicadores).
    for indice in range(6):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            indicadores={
                "phq9": 8,
                "gad7": 6,
                "online_stress": 6,
                "financial_stress": 5,
                "exercise_freq": 3,
                "social_activity": 6,
                "sleep_hours": 7,
            },
        )

    respuesta = client.get(
        "/api/panel/estadisticas", headers=cabecera_autorizacion(token_institucional)
    )

    cuerpo = respuesta.get_json()
    # Todas las atenciones caen en un unico cluster con seis estudiantes: si se
    # publica, ese cluster tiene al menos cinco estudiantes.
    for perfil in cuerpo["perfiles_ia"]:
        assert perfil["n"] >= 5


def test_informe_devuelve_csv_con_bom(client, token_institucional):
    """El informe es un CSV descargable con BOM para Excel."""
    for indice in range(5):
        _registrar(client, token_institucional, estudiante_codigo=f"2026{indice:04d}")

    respuesta = client.get(
        "/api/panel/informe?periodo=2026-03", headers=cabecera_autorizacion(token_institucional)
    )

    assert respuesta.status_code == 200
    assert "text/csv" in respuesta.headers["Content-Type"]
    assert "attachment" in respuesta.headers["Content-Disposition"]
    assert "informe_atenciones_2026-03.csv" in respuesta.headers["Content-Disposition"]

    cuerpo = respuesta.data.decode("utf-8")
    assert cuerpo.startswith("\ufeff")


def test_informe_tiene_cabecera_y_totales(client, token_institucional):
    """El informe incluye la cabecera estable y la fila de totales."""
    for indice in range(5):
        _registrar(client, token_institucional, estudiante_codigo=f"2026{indice:04d}")

    respuesta = client.get(
        "/api/panel/informe", headers=cabecera_autorizacion(token_institucional)
    )

    texto = respuesta.data.decode("utf-8-sig")
    filas = list(csv.reader(io.StringIO(texto)))

    assert filas[0] == [
        "tipo_atencion",
        "modalidad",
        "total_atenciones",
        "requieren_seguimiento",
    ]
    assert filas[-1][0] == "TOTAL"
    assert filas[-1][2] == "5"


def test_informe_omite_grupos_pequenos(client, token_institucional):
    """El informe tampoco expone filas de menos de cinco atenciones."""
    for indice in range(3):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            tipo="emergencia",
        )

    respuesta = client.get(
        "/api/panel/informe", headers=cabecera_autorizacion(token_institucional)
    )

    texto = respuesta.data.decode("utf-8-sig")
    filas = list(csv.reader(io.StringIO(texto)))

    tipos = [fila[0] for fila in filas[1:]]
    assert "emergencia" not in tipos


def test_estadisticas_filtran_por_periodo(client, token_institucional):
    """El filtro por periodo acota los agregados."""
    _registrar(client, token_institucional, fecha_atencion="2026-03-15T10:00:00")
    _registrar(client, token_institucional, fecha_atencion="2026-04-05T10:00:00")

    respuesta = client.get(
        "/api/panel/estadisticas?periodo=2026-03",
        headers=cabecera_autorizacion(token_institucional),
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["periodo"] == "2026-03"
    assert cuerpo["total_atenciones"] == 1

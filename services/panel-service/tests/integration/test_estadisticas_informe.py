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
    assert cuerpo["grupos_omitidos"] is True
    # Con menos de cinco atenciones el total exacto no se publica.
    assert cuerpo["total_atenciones"] is None


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
    assert cuerpo["grupos_omitidos"] is False


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
    assert respuesta.headers["Content-Type"] == "text/csv; charset=utf-8"
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
    # Una sola atencion: el total exacto se suprime por la regla k=5.
    assert cuerpo["total_atenciones"] is None


def _registrar_n(client, token, cantidad, prefijo="2026"):
    """Registra ``cantidad`` atenciones y devuelve el total publicado."""
    for indice in range(cantidad):
        _registrar(
            client,
            token,
            estudiante_codigo=f"{prefijo}{indice:04d}",
        )

    respuesta = client.get(
        "/api/panel/estadisticas",
        headers=cabecera_autorizacion(token),
    )

    cuerpo = respuesta.get_json()
    assert respuesta.status_code == 200
    return cuerpo


def test_total_de_una_atencion_no_se_publica(client, token_institucional):
    """Con menos de cinco atenciones el total exacto se suprime."""
    cuerpo = _registrar_n(client, token_institucional, 1)

    assert cuerpo["total_atenciones"] is None
    assert cuerpo["total_atenciones_estimado"] is False


def test_total_de_tres_atenciones_no_se_publica(client, token_institucional):
    """Tres atenciones siguen por debajo del minimo."""
    cuerpo = _registrar_n(client, token_institucional, 3)

    assert cuerpo["total_atenciones"] is None
    assert cuerpo["total_atenciones_estimado"] is False


def test_total_de_cinco_atenciones_se_publica(client, token_institucional):
    """Con cinco atenciones el total exacto si se publica."""
    cuerpo = _registrar_n(client, token_institucional, 5)

    assert cuerpo["total_atenciones"] == 5
    assert cuerpo["total_atenciones_estimado"] is False


def test_total_de_seis_atenciones_se_publica(client, token_institucional):
    """Con seis atenciones el total exacto si se publica."""
    cuerpo = _registrar_n(client, token_institucional, 6)

    assert cuerpo["total_atenciones"] == 6
    assert cuerpo["total_atenciones_estimado"] is False


def test_total_se_redondea_cuando_hay_grupos_ocultos(client, token_institucional):
    """Con grupos ocultos el total publicado es una cota inferior."""
    for indice in range(5):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026A{indice:04d}",
            tipo="orientacion",
        )
    for indice in range(4):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026B{indice:04d}",
            tipo="emergencia",
        )

    respuesta = client.get(
        "/api/panel/estadisticas",
        headers=cabecera_autorizacion(token_institucional),
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["grupos_omitidos"] is True
    assert cuerpo["total_atenciones"] == 5
    assert cuerpo["total_atenciones_estimado"] is True


def test_requieren_seguimiento_se_suprime_si_es_menor_de_cinco(client, token_institucional):
    """Un conteo de seguimiento entre 1 y 4 no se publica."""
    for indice in range(5):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            seguimiento_requerido=indice == 0,
        )

    respuesta = client.get(
        "/api/panel/estadisticas",
        headers=cabecera_autorizacion(token_institucional),
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["requieren_seguimiento"] is None
    assert cuerpo["requieren_seguimiento_suprimido"] is True


def test_requieren_seguimiento_se_publica_con_cinco_o_mas(client, token_institucional):
    """Con cinco o mas casos de seguimiento el conteo si se publica."""
    for indice in range(5):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026{indice:04d}",
            seguimiento_requerido=True,
        )

    respuesta = client.get(
        "/api/panel/estadisticas",
        headers=cabecera_autorizacion(token_institucional),
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["requieren_seguimiento"] == 5
    assert cuerpo["requieren_seguimiento_suprimido"] is False


def test_atenciones_sin_resolver_se_reportan(client, token_institucional):
    """Las atenciones sin codigo resuelto se reportan como conteo agregado."""
    for indice in range(5):
        _registrar(client, token_institucional, estudiante_codigo=f"2026{indice:04d}")

    respuesta = client.get(
        "/api/panel/estadisticas",
        headers=cabecera_autorizacion(token_institucional),
    )

    cuerpo = respuesta.get_json()
    assert cuerpo["atenciones_sin_resolver"] == 5
    assert cuerpo["atenciones_sin_resolver_suprimido"] is False


def test_fila_total_del_informe_se_suprime(client, token_institucional):
    """La fila TOTAL del CSV respeta la misma regla que la API."""
    _registrar(client, token_institucional)

    respuesta = client.get(
        "/api/panel/informe?periodo=2026-03",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 200
    texto = respuesta.data.decode("utf-8").lstrip("\ufeff")
    filas = list(csv.reader(io.StringIO(texto)))
    total = [fila for fila in filas if fila and fila[0] == "TOTAL"][0]
    assert total[2] == "<5"


def test_fila_total_del_informe_se_redondea(client, token_institucional):
    """Con grupos ocultos la fila TOTAL muestra el total acotado."""
    for indice in range(5):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026A{indice:04d}",
            tipo="orientacion",
        )
    for indice in range(4):
        _registrar(
            client,
            token_institucional,
            estudiante_codigo=f"2026B{indice:04d}",
            tipo="emergencia",
        )

    respuesta = client.get(
        "/api/panel/informe?periodo=2026-03",
        headers=cabecera_autorizacion(token_institucional),
    )

    assert respuesta.status_code == 200
    texto = respuesta.data.decode("utf-8").lstrip("\ufeff")
    filas = list(csv.reader(io.StringIO(texto)))
    total = [fila for fila in filas if fila and fila[0] == "TOTAL"][0]
    assert total[2] == "5"

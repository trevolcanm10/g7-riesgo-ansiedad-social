"""Prueba de extremo a extremo del microservicio Panel Institucional.

Levanta la aplicacion con SQLite en memoria, genera un token JWT valido y
ejercita los endpoints reales por HTTP. No requiere MySQL ni ningun servicio
externo.

Uso:
    python scripts/verificacion_e2e.py
"""

from __future__ import annotations

import json
import os
import sys
from datetime import timedelta

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

import jwt  # noqa: E402
from app.config.settings import TestConfig  # noqa: E402
from app.domain.services.fecha_hora import ahora_utc  # noqa: E402
from app.infrastructure.persistence.db_models import db  # noqa: E402
from run import create_app  # noqa: E402

SECRETO = TestConfig.JWT_SECRET


def token(rol: str = "PERSONAL_UNAYOE") -> str:
    """Genera un token institucional."""
    return jwt.encode(
        {
            "userId": 42,
            "role": rol,
            "exp": int((ahora_utc() + timedelta(hours=1)).timestamp()),
        },
        SECRETO,
        algorithm="HS256",
    )


def main() -> int:
    """Ejecuta la verificacion de extremo a extremo."""
    aplicacion = create_app(TestConfig, crear_esquema=True)

    with aplicacion.app_context():
        db.drop_all()
        db.create_all()

    cliente = aplicacion.test_client()
    cabecera = {"Authorization": f"Bearer {token()}"}
    fallos = []

    def comprobar(nombre: str, condicion: bool, detalle: str = "") -> None:
        """Registra el resultado de una comprobacion."""
        if condicion:
            print(f"  [OK]   {nombre}")
        else:
            print(f"  [FALLA] {nombre} {detalle}")
            fallos.append(nombre)

    print("Health check")
    respuesta = cliente.get("/api/panel/health")
    comprobar("responde 200", respuesta.status_code == 200, str(respuesta.status_code))
    comprobar("servicio identificado", respuesta.get_json()["service"] == "panel")

    print("\nAutenticacion")
    comprobar("sin token responde 401", cliente.get("/api/panel/estadisticas").status_code == 401)

    cabecera_estudiante = {"Authorization": f"Bearer {token('ESTUDIANTE')}"}
    comprobar(
        "rol estudiante responde 403",
        cliente.get("/api/panel/estadisticas", headers=cabecera_estudiante).status_code == 403,
    )

    token_ajeno = jwt.encode({"userId": 1, "role": "ADMINISTRADOR"}, "otro-secreto", algorithm="HS256")
    comprobar(
        "token con firma ajena responde 401",
        cliente.get(
            "/api/panel/estadisticas", headers={"Authorization": f"Bearer {token_ajeno}"}
        ).status_code
        == 401,
    )

    print("\nRegistro de atenciones")
    indicadores = {
        "phq9": 8,
        "gad7": 6,
        "online_stress": 6,
        "financial_stress": 5,
        "exercise_freq": 3,
        "social_activity": 6,
        "sleep_hours": 7,
    }

    for indice in range(6):
        respuesta = cliente.post(
            "/api/panel/atencion",
            json={
                "estudiante_codigo": f"2026{indice:04d}",
                "modalidad": "presencial" if indice % 2 == 0 else "virtual",
                "tipo": "orientacion",
                "fecha_atencion": "2026-03-15T10:00:00",
                "indicadores": indicadores,
                "seguimiento_requerido": indice < 2,
            },
            headers=cabecera,
        )
        if indice == 0:
            comprobar("registro responde 201", respuesta.status_code == 201)
            cuerpo = respuesta.get_json()
            comprobar("devuelve identificador", isinstance(cuerpo.get("id"), int))
            comprobar("asigna cluster", cuerpo.get("cluster_id") is not None, str(cuerpo))

    # Cuatro atenciones de un tipo con menos de cinco: debe quedar oculto.
    for indice in range(4):
        cliente.post(
            "/api/panel/atencion",
            json={
                "estudiante_codigo": f"2027{indice:04d}",
                "modalidad": "telefonica",
                "tipo": "emergencia",
                "fecha_atencion": "2026-03-16T10:00:00",
            },
            headers=cabecera,
        )

    print("\nEstadisticas y privacidad k=5")
    respuesta = cliente.get("/api/panel/estadisticas", headers=cabecera)
    comprobar("estadisticas responden 200", respuesta.status_code == 200)
    estadisticas = respuesta.get_json()

    comprobar("total de atenciones", estadisticas["total_atenciones"] == 10, str(estadisticas))
    comprobar(
        "grupo de 4 no aparece",
        all(grupo["etiqueta"] != "emergencia" for grupo in estadisticas["por_tipo"]),
        str(estadisticas["por_tipo"]),
    )
    comprobar(
        "grupo de 6 si aparece",
        any(grupo["etiqueta"] == "orientacion" for grupo in estadisticas["por_tipo"]),
    )
    comprobar(
        "todos los grupos visibles tienen al menos 5",
        all(grupo["n"] >= 5 for grupo in estadisticas["por_tipo"]),
    )
    comprobar(
        "informa los grupos omitidos",
        estadisticas["grupos_omitidos_por_privacidad"] >= 1,
        str(estadisticas["grupos_omitidos_por_privacidad"]),
    )
    comprobar("incluye la nota de IA", "orientativas" in estadisticas["nota_ia"])

    print("\nInforme CSV")
    respuesta = cliente.get("/api/panel/informe?periodo=2026-03", headers=cabecera)
    comprobar("informe responde 200", respuesta.status_code == 200)
    comprobar(
        "content-disposition con nombre",
        "informe_atenciones_2026-03.csv" in respuesta.headers.get("Content-Disposition", ""),
    )
    texto = respuesta.data.decode("utf-8-sig")
    comprobar("tiene BOM utf-8", respuesta.data.decode("utf-8").startswith("\ufeff"))
    comprobar("no incluye el grupo pequeno", "emergencia" not in texto)
    comprobar("incluye la fila de total", "\nTOTAL," in texto)

    print("\nListado operativo")
    respuesta = cliente.get("/api/panel/atenciones?limite=3", headers=cabecera)
    comprobar("listado responde 200", respuesta.status_code == 200)
    listado = respuesta.get_json()
    comprobar("respeta el limite", len(listado["atenciones"]) == 3)
    comprobar("informa el total", listado["total"] == 10)

    print("\nValidaciones")
    comprobar(
        "modalidad invalida responde 400",
        cliente.post(
            "/api/panel/atencion",
            json={"estudiante_codigo": "1", "modalidad": "x", "tipo": "orientacion"},
            headers=cabecera,
        ).status_code
        == 400,
    )
    comprobar(
        "periodo invalido responde 400",
        cliente.get("/api/panel/estadisticas?periodo=marzo", headers=cabecera).status_code == 400,
    )

    with aplicacion.app_context():
        db.session.remove()
        db.drop_all()

    print()
    if fallos:
        print(f"VERIFICACION FALLIDA: {len(fallos)} comprobacion(es) sin superar")
        for fallo in fallos:
            print(f"  - {fallo}")
        return 1

    print("VERIFICACION SUPERADA: todas las comprobaciones pasaron")
    return 0


if __name__ == "__main__":
    sys.exit(main())

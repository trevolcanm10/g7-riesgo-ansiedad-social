"""Carga atenciones sinteticas de demostracion en la base de datos del panel.

Uso:
    python scripts/seed_demo.py                 # carga 50 atenciones de demostracion
    python scripts/seed_demo.py --cantidad 60   # carga otra cantidad
    python scripts/seed_demo.py --limpiar       # borra las atenciones de demostracion

Las atenciones se guardan con ``registrado_por = 'DEMO-SINTETICO'`` para que
se reconozcan y se borren con una sola sentencia:

    DELETE FROM atenciones WHERE registrado_por = 'DEMO-SINTETICO';

Son datos ficticios, generados de forma determinista. No corresponden a
personas reales, no se deben presentar como evidencia clinica y no sustituyen
las atenciones registradas por el personal institucional.

El script es idempotente: cada ejecucion borra primero las atenciones de
demostracion anteriores antes de insertar las nuevas.
"""

from __future__ import annotations

import argparse
import random
import sys
from datetime import datetime, timedelta
from pathlib import Path

RAIZ_SERVICIO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ_SERVICIO))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(RAIZ_SERVICIO / ".env")

from sqlalchemy import create_engine, text  # noqa: E402

from app.config.settings import construir_engine_options, construir_uri  # noqa: E402
from app.domain.entities.atencion import MODALIDADES, TIPOS_ATENCION  # noqa: E402

ETIQUETA_DEMO = "DEMO-SINTETICO"
CANTIDAD_POR_DEFECTO = 50
SEMILLA = 7

INDICADORES = (
    "phq9",
    "gad7",
    "online_stress",
    "financial_stress",
    "exercise_freq",
    "social_activity",
    "sleep_hours",
)

RANGOS = {
    "phq9": (2.0, 24.0),
    "gad7": (1.0, 21.0),
    "online_stress": (1.0, 10.0),
    "financial_stress": (0.0, 10.0),
    "exercise_freq": (0.0, 7.0),
    "social_activity": (0.0, 10.0),
    "sleep_hours": (4.0, 10.0),
}

INSERTAR = text(
    """
    INSERT INTO atenciones (
        estudiante_codigo, modalidad, tipo, estado,
        phq9, gad7, online_stress, financial_stress,
        exercise_freq, social_activity, sleep_hours,
        cluster_id, notas, seguimiento_requerido, registrado_por,
        fecha_atencion, fecha_creacion, periodo
    ) VALUES (
        :codigo, :modalidad, :tipo, 'registrada',
        :phq9, :gad7, :online_stress, :financial_stress,
        :exercise_freq, :social_activity, :sleep_hours,
        :cluster_id, :notas, :seguimiento, :registrado_por,
        :fecha_atencion, :fecha_creacion, :periodo
    )
    """
)

BORRAR = text("DELETE FROM atenciones WHERE registrado_por = :etiqueta")


def _motor():
    """Crea el motor SQLAlchemy con la configuracion del servicio."""
    opciones = construir_engine_options()
    return create_engine(construir_uri(), **opciones)


def _adaptador_clustering():
    """Devuelve el adaptador del modelo, o None si no esta disponible."""
    try:
        from app.infrastructure.ml.clustering_adapter import ScikitClusteringAdapter

        return ScikitClusteringAdapter()
    except Exception as error:  # pragma: no cover - depende del entorno
        print(f"[AVISO] El modelo de agrupamiento no esta disponible: {error}")
        return None


def _indicadores(azar: random.Random) -> dict:
    """Genera los siete indicadores de la atencion."""
    valores = {}
    for nombre in INDICADORES:
        minimo, maximo = RANGOS[nombre]
        valores[nombre] = round(azar.uniform(minimo, maximo), 2)
    return valores


def _fila(azar: random.Random, indice: int, ahora: datetime, adaptador) -> dict:
    """Construye una atencion de demostracion."""
    dias_atras = azar.randint(0, 110)
    fecha_atencion = (ahora - timedelta(days=dias_atras)).replace(
        hour=azar.randint(8, 17), minute=azar.randint(0, 59), second=0, microsecond=0
    )
    indicadores = _indicadores(azar)
    cluster_id = None
    if adaptador is not None:
        try:
            cluster_id = adaptador.asignar_cluster(indicadores)
        except Exception:  # pragma: no cover - depende del entorno
            cluster_id = None
    seguimiento = azar.random() < 0.2
    return {
        "codigo": f"DEMO{indice:05d}",
        "modalidad": azar.choice(list(MODALIDADES)),
        "tipo": azar.choice(list(TIPOS_ATENCION)),
        "cluster_id": cluster_id,
        "notas": "Atencion de demostracion (dato sintetico).",
        "seguimiento": seguimiento,
        "registrado_por": ETIQUETA_DEMO,
        "fecha_atencion": fecha_atencion,
        "fecha_creacion": ahora,
        "periodo": fecha_atencion.strftime("%Y-%m"),
        **indicadores,
    }


def limpiar(motor) -> int:
    """Borra las atenciones de demostracion."""
    with motor.connect() as conexion:
        resultado = conexion.execute(BORRAR, {"etiqueta": ETIQUETA_DEMO})
        conexion.commit()
        return int(resultado.rowcount or 0)


def sembrar(motor, cantidad: int) -> int:
    """Carga las atenciones de demostracion.

    Borra antes las atenciones de demostracion anteriores, de modo que la
    operacion sea idempotente y no acumule datos falsos.
    """
    limpiar(motor)
    azar = random.Random(SEMILLA)
    ahora = datetime.now().replace(microsecond=0)
    adaptador = _adaptador_clustering()
    filas = [_fila(azar, indice + 1, ahora, adaptador) for indice in range(cantidad)]
    with motor.connect() as conexion:
        for fila in filas:
            conexion.execute(INSERTAR, fila)
        conexion.commit()
    return len(filas)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--limpiar", action="store_true", help="Solo borra los datos de demostracion")
    parser.add_argument("--cantidad", type=int, default=CANTIDAD_POR_DEFECTO)
    argumentos = parser.parse_args()

    motor = _motor()
    if argumentos.limpiar:
        borradas = limpiar(motor)
        print(f"Atenciones de demostracion borradas: {borradas}")
        return 0

    if argumentos.cantidad <= 0:
        print("[ERROR] La cantidad debe ser mayor que cero.")
        return 1

    cargadas = sembrar(motor, argumentos.cantidad)
    print(f"Atenciones de demostracion cargadas: {cargadas} (registrado_por = {ETIQUETA_DEMO})")
    print("Para borrarlas:")
    print(f"    DELETE FROM atenciones WHERE registrado_por = '{ETIQUETA_DEMO}';")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

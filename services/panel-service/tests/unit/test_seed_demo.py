"""Pruebas del script de datos de demostracion (``scripts/seed_demo.py``)."""

from __future__ import annotations

import sys
from datetime import datetime
from pathlib import Path

import pytest
from sqlalchemy import create_engine, text

RAIZ_SERVICIO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(RAIZ_SERVICIO / "scripts"))

import seed_demo  # noqa: E402


@pytest.fixture
def motor():
    """Motor SQLite en memoria con la tabla de atenciones."""
    motor = create_engine("sqlite:///:memory:")
    with motor.connect() as conexion:
        conexion.execute(
            text(
                """
                CREATE TABLE atenciones (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    estudiante_codigo VARCHAR(50) NOT NULL,
                    estudiante_id INTEGER NULL,
                    modalidad VARCHAR(20) NOT NULL,
                    tipo VARCHAR(30) NOT NULL,
                    estado VARCHAR(20) NOT NULL DEFAULT 'registrada',
                    phq9 DOUBLE NULL,
                    gad7 DOUBLE NULL,
                    online_stress DOUBLE NULL,
                    financial_stress DOUBLE NULL,
                    exercise_freq DOUBLE NULL,
                    social_activity DOUBLE NULL,
                    sleep_hours DOUBLE NULL,
                    cluster_id INTEGER NULL,
                    notas TEXT NULL,
                    seguimiento_requerido BOOLEAN NOT NULL DEFAULT 0,
                    registrado_por VARCHAR(120) NULL,
                    fecha_atencion DATETIME NOT NULL,
                    fecha_creacion DATETIME NOT NULL,
                    periodo VARCHAR(7) NOT NULL
                )
                """
            )
        )
        conexion.commit()
    return motor


def _filas(motor):
    with motor.connect() as conexion:
        return conexion.execute(
            text(
                "SELECT estudiante_codigo, modalidad, tipo, registrado_por, periodo, "
                "fecha_atencion, cluster_id FROM atenciones"
            )
        ).fetchall()


def test_sembrar_carga_atenciones_etiquetadas(motor):
    """Las atenciones de demostracion quedan etiquetadas y son borrables."""
    cargadas = seed_demo.sembrar(motor, 12)

    assert cargadas == 12
    filas = _filas(motor)
    assert len(filas) == 12
    for fila in filas:
        assert fila[3] == seed_demo.ETIQUETA_DEMO
        assert fila[4].startswith("20") and len(fila[4]) == 7
        assert fila[5] <= datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def test_sembrar_es_idempotente(motor):
    """Cargar dos veces no acumula atenciones de demostracion."""
    seed_demo.sembrar(motor, 5)
    seed_demo.sembrar(motor, 5)

    assert len(_filas(motor)) == 5


def test_limpiar_borra_solo_las_atencion_es_de_demostracion(motor):
    """La limpieza no toca las atenciones registradas por el personal."""
    seed_demo.sembrar(motor, 4)
    with motor.connect() as conexion:
        conexion.execute(
            text(
                "INSERT INTO atenciones (estudiante_codigo, modalidad, tipo, estado, "
                "seguimiento_requerido, registrado_por, fecha_atencion, fecha_creacion, "
                "periodo) VALUES ('20260001', 'presencial', 'orientacion', 'registrada', "
                "0, 'PERSONAL_UNAYOE', '2026-03-15', '2026-03-15', '2026-03')"
            )
        )
        conexion.commit()

    borradas = seed_demo.limpiar(motor)

    assert borradas == 4
    filas = _filas(motor)
    assert len(filas) == 1
    assert filas[0][3] == "PERSONAL_UNAYOE"

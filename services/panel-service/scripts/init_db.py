"""Aplica el esquema versionado a la base de datos del panel.

Uso:
    python scripts/init_db.py

El esquema vive en ``db/schema.sql`` y es idempotente: ejecutarlo varias
veces no duplica ni altera nada. Las credenciales se leen del ``.env`` del
servicio.

MIGRACIONES
-----------
``CREATE TABLE IF NOT EXISTS`` no modifica una tabla que ya existe. Por eso,
antes de aplicar el esquema se ejecutan las migraciones declaradas en
``MIGRACIONES``, que anaden las columnas incorporadas despues de la primera
version. Cada migracion comprueba ``information_schema`` antes de actuar, de
modo que tambien son idempotentes.
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

RAIZ_SERVICIO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(RAIZ_SERVICIO))

from dotenv import load_dotenv  # noqa: E402

load_dotenv(RAIZ_SERVICIO / ".env")

from app.config.settings import construir_uri  # noqa: E402

RUTA_ESQUEMA = RAIZ_SERVICIO / "db" / "schema.sql"

# Migraciones idempotentes para instalaciones anteriores a la columna
# ``estudiante_id``, que permite correlacionar las atenciones con las
# evaluaciones de riesgo del microservicio de evaluacion.
MIGRACIONES = [
    {
        "columna": "estudiante_id",
        "sql": (
            "ALTER TABLE atenciones "
            "ADD COLUMN estudiante_id INT NULL, "
            "ADD INDEX idx_atenciones_estudiante_id (estudiante_id)"
        ),
    },
]


def aplicar_esquema() -> int:
    """Crea las tablas que aun no existen y aplica las migraciones."""
    from sqlalchemy import create_engine, text

    if not RUTA_ESQUEMA.exists():
        print(f"[ERROR] No se encontro el esquema en {RUTA_ESQUEMA}")
        return 1

    uri = construir_uri()
    motor = create_engine(uri)

    with motor.connect() as conexion:
        for sentencia in _sentencias(RUTA_ESQUEMA.read_text(encoding="utf-8")):
            conexion.execute(text(sentencia))
        conexion.commit()

        for migracion in MIGRACIONES:
            _aplicar_migracion(conexion, migracion)

        conexion.commit()

    motor.dispose()
    print(f"Esquema aplicado correctamente desde {RUTA_ESQUEMA.name}")
    return 0


def _aplicar_migracion(conexion, migracion: dict) -> None:
    """Ejecuta una migracion si la columna todavia no existe."""
    from sqlalchemy import text

    tabla = "atenciones"
    columna = migracion["columna"]

    existe = conexion.execute(
        text(
            "SELECT COUNT(*) FROM information_schema.COLUMNS "
            "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = :tabla "
            "AND COLUMN_NAME = :columna"
        ),
        {"tabla": tabla, "columna": columna},
    ).scalar()

    if existe:
        print(f"  La columna {tabla}.{columna} ya existe.")
        return

    conexion.execute(text(migracion["sql"]))
    print(f"  Migracion aplicada: {tabla}.{columna}")


def _sentencias(contenido: str) -> list:
    """Divide el archivo SQL en sentencias ejecutables."""
    sentencias = []
    for bloque in contenido.split(";"):
        limpia = "\n".join(
            linea
            for linea in bloque.splitlines()
            if not linea.strip().startswith("--")
        ).strip()
        if limpia:
            sentencias.append(limpia)
    return sentencias


if __name__ == "__main__":
    sys.exit(aplicar_esquema())

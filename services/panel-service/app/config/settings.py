"""Configuracion del microservicio.

Las variables sensibles se leen obligatoriamente del archivo ``.env``. No hay
valores por defecto para credenciales: si faltan, el servicio falla de forma
explícita al arrancar.
"""

from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

# Carga el .env del directorio del servicio (dos niveles arriba de este
# archivo). Se usa una ruta absoluta y no load_dotenv() a secas: sin ella el
# .env solo se encontraria si el proceso arrancara desde el directorio del
# servicio, y no desde la raiz del repositorio.
RAIZ_SERVICIO = Path(__file__).resolve().parents[2]
load_dotenv(RAIZ_SERVICIO / ".env")


def _entero(nombre: str, defecto: int) -> int:
    """Lee un entero del entorno con valor por defecto."""
    valor = os.getenv(nombre)
    if valor is None or not str(valor).strip():
        return defecto
    try:
        return int(str(valor).strip())
    except ValueError:
        return defecto


class Config:
    """Configuracion base del panel institucional."""

    # Identificacion del servicio en los health checks.
    SERVICE_NAME = "panel"

    # Puerto HTTP del servicio.
    PORT = _entero("PORT", 5003)

    # Base de datos propia del servicio. Nunca la de otro microservicio.
    DB_USER = os.getenv("DB_USER", "")
    DB_PASS = os.getenv("DB_PASS", "")
    DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT = _entero("DB_PORT", 3306)
    DB_NAME = os.getenv("DB_NAME", "db_panel")

    SQLALCHEMY_DATABASE_URI = os.getenv("SQLALCHEMY_DATABASE_URI", "")
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Secreto compartido con el microservicio de usuarios para validar los
    # tokens. Si falta, las rutas protegidas responden 500 en vez de acceptar
    # peticiones sin verificar.
    JWT_SECRET = os.getenv("JWT_SECRET", "")

    # Base del microservicio de usuarios, consultado por HTTP para resolver
    # la identidad de quien registra una atencion.
    USERS_BASE_URL = os.getenv("USERS_BASE_URL", "")

    # Base del microservicio de evaluacion de riesgo, consultado por HTTP para
    # correlacionar los perfiles de agrupamiento con el nivel de riesgo. Vacio
    # desactiva la correlacion: el panel sigue funcionando sin ella.
    RISK_EVALUATION_BASE_URL = os.getenv("RISK_EVALUATION_BASE_URL", "")

    # Origen permitido para CORS. Por defecto solo el panel local.
    CORS_ALLOW_ORIGIN = os.getenv("CORS_ALLOW_ORIGIN", "http://localhost:5174")

    # Modo debug de Flask.
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"


class TestConfig(Config):
    """Configuracion para las pruebas: SQLite en memoria."""

    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    JWT_SECRET = "secreto-de-pruebas"
    USERS_BASE_URL = ""
    RISK_EVALUATION_BASE_URL = ""
    CORS_ALLOW_ORIGIN = "*"


def construir_uri() -> str:
    """Construye la URI de conexion a MySQL a partir de las variables.

    Si ``SQLALCHEMY_DATABASE_URI`` esta definida, se respeta. Si no, se arma
    con las piezas sueltas. La contraseña se escapa con ``quote_plus`` para
    que los caracteres especiales no rompan la cadena de conexion.
    """
    if Config.SQLALCHEMY_DATABASE_URI:
        return Config.SQLALCHEMY_DATABASE_URI

    from urllib.parse import quote_plus

    usuario = quote_plus(Config.DB_USER)
    contrasena = quote_plus(Config.DB_PASS)

    return (
        f"mysql+pymysql://{usuario}:{contrasena}"
        f"@{Config.DB_HOST}:{Config.DB_PORT}/{Config.DB_NAME}"
        "?charset=utf8mb4"
    )

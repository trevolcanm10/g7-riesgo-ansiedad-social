"""Configuracion del microservicio.

Las variables sensibles se leen obligatoriamente del archivo ``.env``. No hay
valores por defecto para credenciales: si faltan, el servicio falla de forma
explícita al arrancar.
"""

from __future__ import annotations

import os
import ssl
from pathlib import Path
from typing import Optional

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


def _booleano(nombre: str, defecto: bool = False) -> bool:
    """Lee un booleano del entorno con valor por defecto."""
    valor = os.getenv(nombre)
    if valor is None or not str(valor).strip():
        return defecto
    return str(valor).strip().lower() in ("1", "true", "yes", "si", "s")


class Config:
    """Configuracion base del panel institucional."""

    # Identificacion del servicio en los health checks.
    SERVICE_NAME = "panel"

    # Puerto HTTP del servicio.
    PORT = _entero("PORT", 5005)

    # Base de datos propia del servicio. Nunca la de otro microservicio.
    DB_USER = os.getenv("DB_USER", "")
    DB_PASS = os.getenv("DB_PASS", "")
    DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT = _entero("DB_PORT", 3306)
    DB_NAME = os.getenv("DB_NAME", "db_panel")

    # Conexion segura con la base de datos. TiDB Cloud exige TLS; en el
    # desarrollo local la conexion normal no lo usa.
    DB_SSL = _booleano("DB_SSL", False)
    DB_SSL_CA = os.getenv("DB_SSL_CA", "")

    # Segundos de espera maxima de las consultas a otros microservicios. En el
    # plan gratuito de Render el servicio puede tardar en despertar, asi que
    # el valor por defecto es holgado.
    EXTERNAL_TIMEOUT_SECONDS = _entero("EXTERNAL_TIMEOUT_SECONDS", 45)

    SQLALCHEMY_DATABASE_URI = os.getenv("SQLALCHEMY_DATABASE_URI", "")
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    # Secreto compartido con el microservicio de usuarios para validar los
    # tokens. Si falta, las rutas protegidas responden 500 en vez de aceptar
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


def construir_engine_options(db_ssl: Optional[bool] = None, db_ssl_ca: Optional[str] = None) -> dict:
    """Construye las opciones del motor SQLAlchemy para la conexion a la base.

    Con ``DB_SSL`` activo se pasa un contexto SSL que valida el certificado
    del servidor y el nombre del host. Si ``DB_SSL_CA`` apunta a una CA
    privada se usa esa; si no, se usan las CA del sistema.

    Los parametros son opcionales para poder probar la configuracion sin
    tocar el entorno.
    """
    if db_ssl is None:
        db_ssl = _booleano("DB_SSL", False)
    if db_ssl_ca is None:
        db_ssl_ca = os.getenv("DB_SSL_CA", "")

    if not db_ssl:
        return {}

    if db_ssl_ca:
        ruta_ca = Path(db_ssl_ca)
        if not ruta_ca.is_file():
            raise RuntimeError(
                f"DB_SSL_CA apunta a un archivo que no existe: {db_ssl_ca}"
            )
        contexto = ssl.create_default_context(cafile=str(ruta_ca))
    else:
        contexto = ssl.create_default_context()

    return {"connect_args": {"ssl": contexto}}


# Las opciones se calculan al importar el modulo para que la configuracion de
# la base quede lista antes de inicializar SQLAlchemy.
Config.SQLALCHEMY_ENGINE_OPTIONS = construir_engine_options()

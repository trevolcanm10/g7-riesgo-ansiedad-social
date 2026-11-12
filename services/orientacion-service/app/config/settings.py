import json
import os
from pathlib import Path
from typing import List
from urllib.parse import quote_plus
from dotenv import load_dotenv

from app.domain.entities.urgencia_service import DEFAULT_HELP_LINES

# override=False (default): las variables del entorno en producción mandan sobre .env local.
load_dotenv(Path(__file__).resolve().parents[2] / ".env")


def _bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in ("1", "true", "yes", "si")


def _parse_help_lines(raw: str) -> List[str]:
    texto = raw.strip()
    if not texto:
        return list(DEFAULT_HELP_LINES)
    if texto.startswith("["):
        try:
            data = json.loads(texto)
            if isinstance(data, list):
                limpias = [str(item).strip() for item in data if str(item).strip()]
                if limpias:
                    return limpias
        except json.JSONDecodeError:
            pass
    limpias = [item.strip() for item in texto.split("|") if item.strip()]
    return limpias or list(DEFAULT_HELP_LINES)


class Config:
    PORT = int(os.getenv("PORT", "5002"))
    FLASK_DEBUG = _bool("FLASK_DEBUG", False)
    JWT_SECRET = os.getenv("JWT_SECRET", "")

    DB_USER = os.getenv("DB_USER", "root")
    DB_PASS = os.getenv("DB_PASS") or os.getenv("DB_PASSWORD", "")
    DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
    DB_PORT = os.getenv("DB_PORT", "3306")
    DB_NAME = os.getenv("DB_NAME", "db_orientacion")
    DB_SSL = _bool("DB_SSL", True)
    AUTO_CREATE_TABLES = _bool("AUTO_CREATE_TABLES", False)

    CORS_ALLOW_ORIGIN = os.getenv("CORS_ALLOW_ORIGIN", "")
    HELP_LINES = _parse_help_lines(os.getenv("ORIENTACION_HELP_LINES", ""))

    SQLALCHEMY_DATABASE_URI = (
        f"mysql+pymysql://{quote_plus(DB_USER)}:{quote_plus(DB_PASS)}"
        f"@{DB_HOST}:{DB_PORT}/{quote_plus(DB_NAME)}?charset=utf8mb4"
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = (
        {
            "connect_args": {
                "ssl": {"fake_flag_to_enable_tls": True},
                "ssl_verify_cert": False,
                "ssl_verify_identity": False,
            }
        }
        if DB_SSL
        else {}
    )

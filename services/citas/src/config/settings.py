import os
from pathlib import Path

from dotenv import load_dotenv

# override=False: las variables del sistema (Azure/Render) mandan sobre el .env local.
load_dotenv(Path(__file__).resolve().parents[2] / ".env")


def _bool(name: str, default: bool) -> bool:
    return os.environ.get(name, str(default)).strip().lower() in ("1", "true", "yes", "si")


PORT = int(os.environ.get("PORT", "3004"))
JWT_SECRET = os.environ.get("JWT_SECRET", "")
USE_IN_MEMORY = _bool("USE_IN_MEMORY", False)   # solo desarrollo: sin MySQL, datos se pierden

DB_HOST = os.environ.get("DB_HOST", "")
DB_PORT = int(os.environ.get("DB_PORT", "3306"))
DB_NAME = os.environ.get("DB_NAME", "")
DB_USER = os.environ.get("DB_USER", "")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")
DB_SSL = _bool("DB_SSL", True)

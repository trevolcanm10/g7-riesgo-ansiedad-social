from __future__ import annotations

import os
from dataclasses import dataclass


def _environment_bool(name: str, default: str = "false") -> bool:
    value = os.getenv(name, default).strip().lower()
    if value in {"1", "true", "yes", "on"}:
        return True
    if value in {"0", "false", "no", "off"}:
        return False
    raise RuntimeError(f"{name} debe ser true o false")


@dataclass(frozen=True)
class Settings:
    port: int
    db_host: str
    db_port: int
    db_name: str
    db_user: str
    db_password: str
    jwt_secret: str
    db_ssl: bool = False
    db_ssl_ca: str | None = None

    @classmethod
    def from_environment(cls) -> "Settings":
        try:
            port = int(os.getenv("PORT", "5003"))
            db_port = int(os.getenv("DB_PORT", "3306"))
        except ValueError as exc:
            raise RuntimeError("PORT y DB_PORT deben ser números enteros") from exc

        db_ssl = _environment_bool("DB_SSL")
        db_ssl_ca = os.getenv("DB_SSL_CA", "").strip() or None

        required = {
            "DB_HOST": os.getenv("DB_HOST", "").strip(),
            "DB_NAME": os.getenv("DB_NAME", "").strip(),
            "DB_USER": os.getenv("DB_USER", "").strip(),
            "JWT_SECRET": os.getenv("JWT_SECRET", ""),
        }
        missing = [name for name, value in required.items() if not value]
        if missing:
            raise RuntimeError(
                "Faltan variables de entorno requeridas: " + ", ".join(missing)
            )
        if port < 1 or port > 65535 or db_port < 1 or db_port > 65535:
            raise RuntimeError("PORT y DB_PORT deben estar entre 1 y 65535")

        return cls(
            port=port,
            db_host=required["DB_HOST"],
            db_port=db_port,
            db_name=required["DB_NAME"],
            db_user=required["DB_USER"],
            db_password=os.getenv("DB_PASSWORD", ""),
            jwt_secret=required["JWT_SECRET"],
            db_ssl=db_ssl,
            db_ssl_ca=db_ssl_ca,
        )

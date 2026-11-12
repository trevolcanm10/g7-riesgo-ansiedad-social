"""Fixtures compartidas de las pruebas del Panel Institucional.

Las pruebas corren sobre SQLite en memoria: no tocan la base de datos MySQL
ni requieren conexion externa.
"""

from __future__ import annotations

import os
import sys
from datetime import datetime, timedelta

import jwt
import pytest

RAIZ_SERVICIO = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, RAIZ_SERVICIO)

from app.config.settings import TestConfig  # noqa: E402
from app.infrastructure.persistence.db_models import db  # noqa: E402
from run import create_app  # noqa: E402

SECRETO_PRUEBAS = TestConfig.JWT_SECRET


@pytest.fixture
def app():
    """Aplicacion Flask con base de datos aislada en memoria."""
    aplicacion = create_app(TestConfig, crear_esquema=True)

    with aplicacion.app_context():
        db.drop_all()
        db.create_all()
        yield aplicacion
        db.session.remove()
        db.drop_all()


@pytest.fixture
def client(app):
    """Cliente HTTP de pruebas."""
    return app.test_client()


def token_para(user_id: int = 42, rol: str = "PERSONAL_UNAYOE", **extra) -> str:
    """Genera un token JWT valido para las pruebas."""
    payload = {"userId": user_id, "role": rol}
    payload.update(extra)
    return jwt.encode(payload, SECRETO_PRUEBAS, algorithm="HS256")


def cabecera_autorizacion(token: str) -> dict:
    """Construye la cabecera Authorization con el token."""
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def token_institucional():
    """Token de un miembro del personal institucional."""
    return token_para(rol="PERSONAL_UNAYOE")


@pytest.fixture
def token_admin():
    """Token de un administrador."""
    return token_para(user_id=1, rol="ADMINISTRADOR")


@pytest.fixture
def token_estudiante():
    """Token de un estudiante, sin acceso al panel."""
    return token_para(user_id=7, rol="ESTUDIANTE")


@pytest.fixture
def fechas():
    """Fechas de referencia para construir atenciones de prueba."""
    return {
        "actual": datetime(2026, 3, 15, 10, 0, 0),
        "anterior": datetime(2026, 2, 10, 9, 30, 0),
        "otro_mes": datetime(2026, 4, 5, 11, 0, 0),
    }


@pytest.fixture
def indicadores_completos():
    """Indicadores validos del contrato de evaluacion de riesgo."""
    return {
        "phq9": 8,
        "gad7": 6,
        "online_stress": 6,
        "financial_stress": 5,
        "exercise_freq": 3,
        "social_activity": 6,
        "sleep_hours": 7,
    }

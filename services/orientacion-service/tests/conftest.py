from datetime import datetime, timedelta, timezone
import os
import sys

import jwt
import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.infrastructure.persistence.db_models import db  # noqa: E402
from run import create_app  # noqa: E402

TEST_JWT_SECRET = "test-secret-orientacion-min-32-bytes-key"


class TestConfig:
    TESTING = True
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    JWT_SECRET = TEST_JWT_SECRET
    CORS_ALLOW_ORIGIN = "http://localhost:5173"
    AUTO_CREATE_TABLES = False
    HELP_LINES = None


def build_token(
    user_id=101,
    role="ESTUDIANTE",
    secret=TEST_JWT_SECRET,
    exp_offset_seconds=3600,
    include_exp=True,
) -> str:
    payload = {}
    if user_id is not None:
        payload["userId"] = user_id
    if role is not None:
        payload["role"] = role
    if include_exp:
        payload["exp"] = datetime.now(timezone.utc) + timedelta(
            seconds=exp_offset_seconds
        )
    return jwt.encode(payload, secret, algorithm="HS256")


def auth_headers(user_id=101, role="ESTUDIANTE", **kwargs) -> dict:
    token = build_token(user_id=user_id, role=role, **kwargs)
    return {"Authorization": f"Bearer {token}"}


@pytest.fixture
def app():
    application = create_app(TestConfig)
    with application.app_context():
        db.drop_all()
        db.create_all()
        yield application
        db.drop_all()


@pytest.fixture
def client(app):
    return app.test_client()

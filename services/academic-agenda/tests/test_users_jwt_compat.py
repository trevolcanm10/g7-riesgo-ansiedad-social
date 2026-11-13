from datetime import datetime, timedelta, timezone

import jwt
import pytest

from src.domain.errors import InvalidActivityError
from src.infrastructure.services.jwt_token_service import JwtTokenService


def test_accepts_users_jwt_claims_and_normalizes_user_id():
    service = JwtTokenService("shared-test-secret")
    token = jwt.encode(
        {
            "userId": 42,
            "role": "ESTUDIANTE",
            "iat": datetime.now(timezone.utc),
            "exp": datetime.now(timezone.utc) + timedelta(hours=1),
        },
        "shared-test-secret",
        algorithm="HS256",
    )
    claims = service.verify_access_token(token)
    assert claims["user_id"] == 42
    assert claims["role"] == "ESTUDIANTE"


def test_agenda_issues_users_compatible_claims():
    service = JwtTokenService("shared-test-secret")
    token = service.generate_access_token(42, "ESTUDIANTE")
    payload = jwt.decode(token, "shared-test-secret", algorithms=["HS256"])
    assert payload["userId"] == 42
    assert "user_id" not in payload
    assert service.verify_access_token(token)["user_id"] == 42


@pytest.mark.parametrize("claims,secret", [
    ({"userId": 42, "role": "ESTUDIANTE", "exp": 1}, "shared-test-secret"),
    ({"userId": 42, "role": "OTRO"}, "shared-test-secret"),
    ({"userId": 42, "role": "ESTUDIANTE"}, "shared-test-secret"),
    ({"userId": 42, "role": "ESTUDIANTE"}, "wrong-secret"),
])
def test_rejects_expired_invalid_role_or_signature(claims, secret):
    token = jwt.encode(claims, secret, algorithm="HS256")
    with pytest.raises(InvalidActivityError):
        JwtTokenService("shared-test-secret").verify_access_token(token)

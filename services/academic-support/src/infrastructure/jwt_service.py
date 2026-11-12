from __future__ import annotations

from typing import Any

import jwt

from ..domain.entities import ROLES
from ..domain.errors import DomainError


def verify_access_token(token: str, secret: str) -> dict[str, Any]:
    try:
        payload = jwt.decode(
            token,
            secret,
            algorithms=["HS256"],
            options={"require": ["exp"]},
        )
    except jwt.ExpiredSignatureError as exc:
        raise DomainError("Token inválido o expirado", 401) from exc
    except jwt.InvalidTokenError as exc:
        raise DomainError("Token inválido o expirado", 401) from exc

    user_id = payload.get("userId")
    role = payload.get("role")
    if (
        isinstance(user_id, bool)
        or not isinstance(user_id, int)
        or user_id <= 0
        or role not in ROLES
    ):
        raise DomainError("Token inválido o expirado", 401)
    return {"user_id": user_id, "role": role}

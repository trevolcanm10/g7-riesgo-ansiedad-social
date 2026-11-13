import jwt
from datetime import datetime, timedelta, timezone

from ...domain.services.token_service import TokenService
from ...domain.errors import InvalidActivityError


USER_ROLES = {"ESTUDIANTE", "PERSONAL_UNAYOE", "ADMINISTRADOR"}


class JwtTokenService(TokenService):
    """Implementación JWT del servicio de tokens."""

    def __init__(self, secret: str, expires_minutes: int = 60 * 24 * 7) -> None:
        if not secret:
            raise InvalidActivityError("JWT_SECRET no está configurado")
        self._secret = secret
        self._expires_minutes = expires_minutes

    def verify_access_token(self, token: str) -> dict:
        try:
            payload = jwt.decode(
                token,
                self._secret,
                algorithms=["HS256"],
                options={"require": ["exp"]},
            )
            user_id = payload.get("userId", payload.get("user_id"))
            if (
                type(user_id) is not int
                or user_id <= 0
                or payload.get("role") not in USER_ROLES
            ):
                raise jwt.InvalidTokenError("Claims inválidos")
            return {"user_id": user_id, "role": payload["role"]}
        except jwt.ExpiredSignatureError as exc:
            raise InvalidActivityError("Token expirado") from exc
        except jwt.InvalidTokenError as exc:
            raise InvalidActivityError("Token inválido") from exc

    def generate_access_token(self, user_id: int, role: str) -> str:
        now = datetime.now(timezone.utc)
        payload = {
            "userId": user_id,
            "role": role,
            "iat": now,
            "exp": now + timedelta(minutes=self._expires_minutes),
        }
        return jwt.encode(payload, self._secret, algorithm="HS256")

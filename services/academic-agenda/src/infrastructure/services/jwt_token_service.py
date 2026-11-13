import jwt
from datetime import datetime, timedelta, timezone

from ...domain.services.token_service import TokenService
from ...domain.errors import InvalidActivityError


class JwtTokenService(TokenService):
    """Implementación JWT del servicio de tokens."""

    def __init__(self, secret: str, expires_minutes: int = 60 * 24 * 7) -> None:
        if not secret:
            raise InvalidActivityError("JWT_SECRET no está configurado")
        self._secret = secret
        self._expires_minutes = expires_minutes

    def verify_access_token(self, token: str) -> dict:
        try:
            payload = jwt.decode(token, self._secret, algorithms=["HS256"])
            if "user_id" not in payload:
                raise jwt.InvalidTokenError("user_id ausente")
            return payload
        except jwt.ExpiredSignatureError as exc:
            raise InvalidActivityError("Token expirado") from exc
        except jwt.InvalidTokenError as exc:
            raise InvalidActivityError("Token inválido") from exc

    def generate_access_token(self, user_id: int, role: str) -> str:
        now = datetime.now(timezone.utc)
        payload = {
            "user_id": user_id,
            "role": role,
            "iat": now,
            "exp": now + timedelta(minutes=self._expires_minutes),
        }
        return jwt.encode(payload, self._secret, algorithm="HS256")
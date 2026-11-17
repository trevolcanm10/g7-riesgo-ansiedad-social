import jwt

from ...domain.services.token_service import TokenService
from ...domain.errors import InvalidActivityError


USER_ROLES = {"ESTUDIANTE", "PERSONAL_UNAYOE", "ADMINISTRADOR"}


class JwtTokenService(TokenService):
    """Implementación JWT del servicio de tokens."""

    def __init__(self, secret: str) -> None:
        if not secret:
            raise InvalidActivityError("JWT_SECRET no está configurado")
        self._secret = secret

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

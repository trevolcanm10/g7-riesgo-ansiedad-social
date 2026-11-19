from typing import Tuple
import jwt

from app.application.interfaces.token_service_port import ITokenService
from app.domain.entities.solicitud import Role

_ROLES = {r.value for r in Role}


class JwtTokenService(ITokenService):
    """Valida el mismo JWT que emite el servicio Users (HS256, payload {userId, role})."""

    def __init__(self, secret: str):
        if not secret:
            raise RuntimeError("JWT_SECRET no está configurado")
        self._secret = secret

    def verify_access_token(self, token: str) -> Tuple[int, str]:
        try:
            payload = jwt.decode(
                token,
                self._secret,
                algorithms=["HS256"],
                options={"require": ["exp"]},
            )
        except jwt.PyJWTError as exc:
            raise ValueError("Token inválido o expirado") from exc

        user_id = payload.get("userId")
        role = payload.get("role")
        if (
            isinstance(user_id, bool)
            or not isinstance(user_id, int)
            or user_id <= 0
            or role not in _ROLES
        ):
            raise ValueError("Token inválido")
        return user_id, role

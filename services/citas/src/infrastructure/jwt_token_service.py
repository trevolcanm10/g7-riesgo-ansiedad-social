import jwt

from src.domain.model import Role
from src.domain.ports import TokenService

_ROLES = {r.value for r in Role}


class JwtTokenService(TokenService):
    """Valida el mismo JWT que emite el servicio Users (HS256, payload {userId, role})."""

    def __init__(self, secret: str):
        if not secret:
            raise RuntimeError("JWT_SECRET no está configurado")
        self._secret = secret

    def verify_access_token(self, token):
        try:
            # exp obligatorio: Users emite tokens de 1 h; uno sin caducidad no debe aceptarse.
            payload = jwt.decode(token, self._secret, algorithms=["HS256"],
                                 options={"require": ["exp"]})
        except jwt.PyJWTError as exc:
            raise ValueError("Token inválido o expirado") from exc
        user_id, role = payload.get("userId"), payload.get("role")
        if (not isinstance(user_id, int) or isinstance(user_id, bool) or user_id <= 0
                or role not in _ROLES):
            raise ValueError("Token inválido")
        return user_id, role

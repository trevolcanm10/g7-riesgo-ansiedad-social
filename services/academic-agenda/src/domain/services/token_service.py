from abc import ABC, abstractmethod


class TokenService(ABC):
    """Puerto de servicio de tokens JWT."""

    @abstractmethod
    def verify_access_token(self, token: str) -> dict:
        """Verifica y decodifica un token JWT. Devuelve el payload."""

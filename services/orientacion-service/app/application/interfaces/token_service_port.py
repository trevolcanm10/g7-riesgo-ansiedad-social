from abc import ABC, abstractmethod
from typing import Tuple


class ITokenService(ABC):
    @abstractmethod
    def verify_access_token(self, token: str) -> Tuple[int, str]:
        """Valida el JWT y retorna (user_id, role)."""
        pass

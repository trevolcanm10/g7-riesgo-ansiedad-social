"""Puerto de consulta al microservicio de usuarios.

Regla de aislamiento de datos: este servicio **no** accede a la base de
datos de ``users``. Cuando necesita informacion de otro microservicio, la
obtiene por HTTP a traves de este puerto.

El uso previsto es resolver la identidad de la persona que registra una
atencion, reenviando su token al servicio ``users``.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional


class IPersonalExternoPort(ABC):
    """Contrato para resolver la identidad del personal institucional."""

    @abstractmethod
    def resolver_identidad(self, token: str) -> Optional[str]:
        """Resuelve el nombre de la persona a partir de su token.

        Delega en el microservicio ``users`` mediante HTTP. Devuelve ``None``
        si el servicio no responde o el token no es valido: el registro de la
        atencion no debe fallar por un problema de un servicio externo.
        """

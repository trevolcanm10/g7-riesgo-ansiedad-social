"""Puerto de consulta al microservicio de usuarios.

REGLA DE AISLAMIENTO DE DATOS
------------------------------
Este servicio **no** lee la base de datos de ``users``. Necesita resolver el
codigo de un estudiante a su identificador numerico para poder correlacionar
con las evaluaciones de riesgo, y lo hace por HTTP a traves de este puerto.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Optional


class IUsuariosPort(ABC):
    """Contrato para resolver la identidad de un estudiante."""

    @abstractmethod
    def resolver_id(self, codigo: str, token: str) -> Optional[int]:
        """Devuelve el identificador numerico del estudiante con ese codigo.

        Devuelve ``None`` si el estudiante no existe o si el servicio no
        responde: registrar una atencion no debe depender de la disponibilidad
        de otro microservicio.
        """

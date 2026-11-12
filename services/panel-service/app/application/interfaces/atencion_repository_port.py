"""Puerto de persistencia de atenciones.

La capa de aplicacion depende de esta abstraccion, nunca de SQLAlchemy.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import Dict, List, Optional, Tuple

from app.domain.entities.atencion import Atencion


class IAtencionRepository(ABC):
    """Contrato de almacenamiento de atenciones."""

    @abstractmethod
    def guardar(self, atencion: Atencion) -> Atencion:
        """Persiste una atencion y devuelve la entidad con su identificador."""

    @abstractmethod
    def listar(
        self,
        limite: int = 50,
        offset: int = 0,
        tipo: Optional[str] = None,
        modalidad: Optional[str] = None,
        periodo: Optional[str] = None,
    ) -> Tuple[List[Atencion], int]:
        """Devuelve una pagina de atenciones y el total de atenciones.

        ``periodo`` usa el formato ``YYYY-MM``.
        """

    @abstractmethod
    def contar_por_dimension(self, dimension: str, periodo: Optional[str] = None) -> List[Tuple[str, int]]:
        """Cuenta atenciones agrupadas por ``dimension``.

        ``dimension`` admite ``tipo``, ``modalidad``, ``estado`` y ``periodo``.
        Devuelve tuplas ``(etiqueta, n)`` ordenadas de mayor a menor.
        """

    @abstractmethod
    def contar_por_cluster(self, periodo: Optional[str] = None) -> List[Tuple[Optional[int], int]]:
        """Cuenta atenciones agrupadas por cluster asignado.

        La etiqueta es ``None`` cuando la atencion no tiene indicadores y por
        tanto no recibió cluster.
        """

    @abstractmethod
    def contar_por_seguimiento(self, periodo: Optional[str] = None) -> int:
        """Cuenta atenciones que requieren seguimiento."""

    @abstractmethod
    def listar_estudiantes_por_cluster(
        self, periodo: Optional[str] = None
    ) -> Dict[int, List[int]]:
        """Devuelve los identificadores de estudiantes agrupados por cluster.

        Se usa para correlacionar los perfiles de agrupamiento con el nivel de
        riesgo publicado por el microservicio de evaluacion.
        """

    @abstractmethod
    def total_atencioness(self, periodo: Optional[str] = None) -> int:
        """Cuenta el total de atenciones del periodo."""

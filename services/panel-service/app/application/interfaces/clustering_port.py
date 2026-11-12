"""Puerto de agrupamiento (clustering).

Define el contrato de inferencia del modelo de perfiles. La implementacion
concreta vive en infraestructura y carga el artefacto ``.joblib``.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import List, Optional

from app.domain.entities.perfil_cluster import PerfilCluster


class IClusteringPort(ABC):
    """Contrato para asignar perfiles y describir los perfiles existentes."""

    @abstractmethod
    def asignar_cluster(self, indicadores: dict) -> Optional[int]:
        """Devuelve el cluster del estudiante segun sus indicadores.

        Devuelve ``None`` si no hay indicadores suficientes o si el modelo no
        esta disponible. Los resultados son estimaciones orientativas: esta
        clasificacion no es un diagnostico clinico.
        """

    @abstractmethod
    def perfiles_disponibles(self) -> List[PerfilCluster]:
        """Devuelve la descripcion de cada perfil connue por el modelo."""

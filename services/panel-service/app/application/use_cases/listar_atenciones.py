"""Caso de uso: listar atenciones registradas con paginacion y filtros."""

from __future__ import annotations

from typing import List, Optional, Tuple

from app.application.interfaces.atencion_repository_port import IAtencionRepository
from app.domain.entities.atencion import Atencion


class ListarAtenciones:
    """Devuelve una pagina de atenciones y el total del filtro."""

    def __init__(self, repository: IAtencionRepository) -> None:
        self._repository = repository

    def execute(
        self,
        limite: int = 50,
        offset: int = 0,
        tipo: Optional[str] = None,
        modalidad: Optional[str] = None,
        periodo: Optional[str] = None,
    ) -> Tuple[List[Atencion], int]:
        """Aplica los filtros indicados y devuelve ``(atenciones, total)``."""
        return self._repository.listar(
            limite=limite,
            offset=offset,
            tipo=tipo,
            modalidad=modalidad,
            periodo=periodo,
        )

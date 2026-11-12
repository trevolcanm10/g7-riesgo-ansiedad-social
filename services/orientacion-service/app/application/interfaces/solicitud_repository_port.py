from abc import ABC, abstractmethod
from typing import List, Optional
from app.domain.entities.solicitud import SolicitudOrientacion


class ISolicitudRepository(ABC):
    @abstractmethod
    def save(self, solicitud: SolicitudOrientacion) -> SolicitudOrientacion:
        pass

    @abstractmethod
    def find_all(
        self,
        estado: Optional[str] = None,
        prioridad: Optional[str] = None,
        estudiante_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[SolicitudOrientacion]:
        pass

    @abstractmethod
    def find_by_id(self, solicitud_id: int) -> Optional[SolicitudOrientacion]:
        pass

    @abstractmethod
    def update(self, solicitud: SolicitudOrientacion) -> SolicitudOrientacion:
        pass

    @abstractmethod
    def count_by_tema(self) -> List[dict]:
        pass

    @abstractmethod
    def ping(self) -> bool:
        pass

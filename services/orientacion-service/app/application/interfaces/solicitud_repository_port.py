from abc import ABC, abstractmethod
from datetime import datetime
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
    def atender_si_pendiente(
        self,
        solicitud_id: int,
        respuesta_escrita: str,
        atendido_por: int,
        fecha_atencion: datetime,
        tema_confirmado: Optional[str] = None,
        prioridad_confirmada: Optional[str] = None,
    ) -> Optional[SolicitudOrientacion]:
        pass

    @abstractmethod
    def count_by_tema(self) -> List[dict]:
        pass

    @abstractmethod
    def ping(self) -> bool:
        pass

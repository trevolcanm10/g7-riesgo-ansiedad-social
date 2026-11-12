from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import List, Optional


class Role(str, Enum):
    ESTUDIANTE = "ESTUDIANTE"
    PERSONAL_UNAYOE = "PERSONAL_UNAYOE"
    ADMINISTRADOR = "ADMINISTRADOR"


TEMAS_VALIDOS = ("academico", "ansiedad_estres", "economico", "familiar", "personal")
PRIORIDADES_VALIDAS = ("alta", "media", "baja")
ESTADOS_VALIDOS = ("pendiente", "atendida")


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _iso_utc(dt: Optional[datetime]) -> Optional[str]:
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    else:
        dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


@dataclass
class UrgenciaAnalisis:
    es_urgente: bool
    coincidencias: List[str]
    lineas_ayuda: List[str]


@dataclass
class SolicitudOrientacion:
    estudiante_id: int
    mensaje: str
    comparte_evaluacion_riesgo: bool = False
    evaluacion_riesgo_id: Optional[int] = None

    id: Optional[int] = None
    tema_sugerido: Optional[str] = None
    prioridad_sugerida: Optional[str] = None
    urgencia_detectada: bool = False
    estado: str = "pendiente"

    tema_confirmado: Optional[str] = None
    prioridad_confirmada: Optional[str] = None
    respuesta_escrita: Optional[str] = None
    atendido_por: Optional[int] = None

    fecha_creacion: datetime = field(default_factory=utc_now)
    fecha_atencion: Optional[datetime] = None

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "estudiante_id": self.estudiante_id,
            "mensaje": self.mensaje,
            "comparte_evaluacion_riesgo": self.comparte_evaluacion_riesgo,
            "evaluacion_riesgo_id": self.evaluacion_riesgo_id,
            "tema_sugerido": self.tema_sugerido,
            "prioridad_sugerida": self.prioridad_sugerida,
            "urgencia_detectada": self.urgencia_detectada,
            "estado": self.estado,
            "tema_confirmado": self.tema_confirmado,
            "prioridad_confirmada": self.prioridad_confirmada,
            "respuesta_escrita": self.respuesta_escrita,
            "atendido_por": self.atendido_por,
            "fecha_creacion": _iso_utc(self.fecha_creacion),
            "fecha_atencion": _iso_utc(self.fecha_atencion),
        }

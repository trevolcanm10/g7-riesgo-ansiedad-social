from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional, List

@dataclass
class UrgenciaAnalisis:
    es_urgente: bool
    coincidencias: List[str]
    lineas_ayuda: List[str]

@dataclass
class SolicitudOrientacion:
    estudiante_id: str
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
    atendido_por: Optional[str] = None

    fecha_creacion: datetime = field(default_factory=datetime.utcnow)
    fecha_atencion: Optional[datetime] = None

    def to_dict(self):
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
            "fecha_creacion": self.fecha_creacion.isoformat() if self.fecha_creacion else None,
            "fecha_atencion": self.fecha_atencion.isoformat() if self.fecha_atencion else None
        }

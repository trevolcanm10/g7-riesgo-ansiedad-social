"""Entidad de dominio: atencion registrada al estudiante.

Es la unidad central del Panel Institucional. No depende de Flask, SQLAlchemy
ni de ningun detalle de infraestructura.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime
from typing import Optional

from app.domain.services.fecha_hora import ahora_utc

# Modalidades de atencion admitidas por el servicio.
MODALIDADES = (
    "presencial",
    "virtual",
    "telefonica",
    "correo",
)

# Tipos de atencion admitidos por el servicio.
TIPOS_ATENCION = (
    "orientacion",
    "seguimiento",
    "derivacion",
    "evaluacion",
    "emergencia",
)

# Estados del ciclo de una atencion.
ESTADOS = (
    "registrada",
    "en_seguimiento",
    "cerrada",
)


@dataclass
class Atencion:
    """Registro de una atencion institucional a un estudiante.

    ``indicadores`` contiene los siete valores del contrato de evaluacion de
    riesgo (PHQ-9, GAD-7, estres en linea, estres financiero, frecuencia de
    ejercicio, actividad social y horas de sueno). Todos son opcionales: si
    no se registran, la atencion queda sin perfil de agrupamiento.
    """

    estudiante_codigo: str
    modalidad: str
    tipo: str
    fecha_atencion: datetime
    indicadores: dict = field(default_factory=dict)
    notas: Optional[str] = None
    seguimiento_requerido: bool = False
    registrado_por: Optional[str] = None
    cluster_id: Optional[int] = None
    # Identificador numerico del estudiante en el servicio de usuarios. Se
    # resuelve por HTTP y permite correlacionar con el nivel de riesgo sin
    # compartir bases de datos.
    estudiante_id: Optional[int] = None

    id: Optional[int] = None
    estado: str = "registrada"
    fecha_creacion: datetime = field(default_factory=ahora_utc)

    def to_dict(self) -> dict:
        """Serializa la atencion para la capa de presentacion."""
        return {
            "id": self.id,
            "estudiante_codigo": self.estudiante_codigo,
            "estudiante_id": self.estudiante_id,
            "modalidad": self.modalidad,
            "tipo": self.tipo,
            "estado": self.estado,
            "indicadores": dict(self.indicadores),
            "cluster_id": self.cluster_id,
            "seguimiento_requerido": self.seguimiento_requerido,
            "registrado_por": self.registrado_por,
            "notas": self.notas,
            "fecha_atencion": self.fecha_atencion.isoformat() if self.fecha_atencion else None,
            "fecha_creacion": self.fecha_creacion.isoformat() if self.fecha_creacion else None,
        }

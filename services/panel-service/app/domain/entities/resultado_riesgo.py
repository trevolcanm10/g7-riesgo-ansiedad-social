"""Resultado de consultar el conteo de niveles de riesgo de un conjunto de estudiantes.

Solo se viajan conteos por nivel, nunca el riesgo individual de un
estudiante: el microservicio de evaluacion responde con el agregado y el panel
no puede reconstruir datos personales a partir de el.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Dict, Optional

from app.domain.entities.motivo_riesgo import MotivoRiesgo


@dataclass(frozen=True)
class ResultadoRiesgo:
    """Conteos por nivel de riesgo y el motivo de su disponibilidad.

    ``total`` es ``None`` cuando el servicio de evaluacion suprimio el dato
    por la regla de privacidad (grupo con menos de cinco estudiantes).
    ``conteos`` esta vacio cuando no hay datos o cuando el motivo es un
    fallo de configuracion o de servicio.
    """

    total: Optional[int] = None
    suprimido: bool = False
    conteos: Dict[str, int] = field(default_factory=dict)
    motivo: MotivoRiesgo = MotivoRiesgo.SIN_DATOS

    @property
    def disponible(self) -> bool:
        """Indica si hay conteos publicables."""
        return self.motivo is MotivoRiesgo.DISPONIBLE

    def to_dict(self) -> dict:
        """Representacion serializable del resultado."""
        return {
            "total": self.total,
            "suprimido": self.suprimido,
            "conteos": dict(self.conteos),
            "motivo": self.motivo.value,
        }

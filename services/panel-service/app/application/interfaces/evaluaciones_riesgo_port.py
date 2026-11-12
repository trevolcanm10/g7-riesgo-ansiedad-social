"""Puerto de consulta al microservicio de evaluacion de riesgo.

REGLA DE AISLAMIENTO DE DATOS
------------------------------
Este servicio **no** lee la base de datos de ``riskEvaluation``. Cuando
necesita informacion de ese microservicio la obtiene por HTTP, a traves de
este puerto.

El servicio expone ``GET /risk-evaluations/me/history``, que devuelve el
historial de evaluaciones del usuario autenticado. Para consultar las
evaluaciones de varios estudiantes el panel agregaria el endpoint
correspondiente en ``riskEvaluation``; mientras tanto, el adaptador trabaja
con lo que ese servicio publica hoy.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import List, Optional


class EvaluacionRiesgo:
    """Evaluacion de riesgo tal como la publica ``riskEvaluation``.

    Es una estructura de datos simple, no una entidad de dominio: el panel
    no tiene (ni debe tener) el modelo de ``riskEvaluation``.
    """

    def __init__(
        self,
        usuario_id: int,
        probabilidad_ansiedad: float,
        nivel_riesgo: str,
        fecha: Optional[str] = None,
    ) -> None:
        self.usuario_id = usuario_id
        self.probabilidad_ansiedad = probabilidad_ansiedad
        self.nivel_riesgo = nivel_riesgo
        self.fecha = fecha

    def to_dict(self) -> dict:
        """Serializa la evaluacion para la capa de presentacion."""
        return {
            "usuario_id": self.usuario_id,
            "probabilidad_ansiedad": self.probabilidad_ansiedad,
            "nivel_riesgo": self.nivel_riesgo,
            "fecha": self.fecha,
        }


class IEvaluacionesRiesgoPort(ABC):
    """Contrato para obtener evaluaciones de riesgo de forma agregada."""

    @abstractmethod
    def listar_evaluaciones(self, usuario_ids: List[int]) -> List[EvaluacionRiesgo]:
        """Devuelve la ultima evaluacion de riesgo de cada usuario indicado.

        Devuelve una lista vacia si el servicio no esta disponible: el panel
        debe funcionar aunque ``riskEvaluation`` no responda. Es una degradacion
        deliberada, no un error.
        """

"""Adaptador HTTP para consultar evaluaciones de riesgo.

Regla de aislamiento de datos: este servicio **no** lee la base de datos de
``riskEvaluation``. Las evaluaciones se piden por HTTP al endpoint agregado
que expone ese servicio.

El servicio de riesgo expone ``GET /risk-evaluations/summary``, que devuelve
la ultima evaluacion de cada estudiante (nivel de riesgo y probabilidad), sin
identificadores personales mas alla del identificador del usuario.

Si el servicio no esta disponible, el adaptador devuelve una lista vacia: el
panel debe funcionar aunque el servicio de evaluacion no responda. Es una
degradacion deliberada, no un error.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.parse
import urllib.request
from typing import List, Optional

from app.application.interfaces.evaluaciones_riesgo_port import (
    EvaluacionRiesgo,
    IEvaluacionesRiesgoPort,
)

logger = logging.getLogger(__name__)

# Segundos de espera maxima antes de abandonar la consulta externa.
TIMEOUT_SEGUNDOS = 8


class EvaluacionesRiesgoClient(IEvaluacionesRiesgoPort):
    """Consulta las evaluaciones de riesgo por HTTP."""

    def __init__(self, url_base: Optional[str] = None, timeout: int = TIMEOUT_SEGUNDOS) -> None:
        self._url_base = (url_base or "").rstrip("/")
        self._timeout = timeout

    def listar_evaluaciones(self, usuario_ids: List[int]) -> List[EvaluacionRiesgo]:
        """Devuelve la ultima evaluacion de riesgo de cada estudiante."""
        if not self._url_base or not usuario_ids:
            return []

        ids = ",".join(str(identificador) for identificador in usuario_ids)
        url = f"{self._url_base}/risk-evaluations/summary?userIds={urllib.parse.quote(ids)}"

        peticion = urllib.request.Request(url, method="GET")
        peticion.add_header("Accept", "application/json")

        try:
            with urllib.request.urlopen(peticion, timeout=self._timeout) as respuesta:
                if respuesta.status != 200:
                    logger.warning(
                        "El servicio de riesgo respondio %s; se omite la correlacion.",
                        respuesta.status,
                    )
                    return []
                cuerpo = respuesta.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            logger.warning("El servicio de riesgo respondio HTTP %s.", error.code)
            return []
        except urllib.error.URLError as error:
            logger.warning("No se pudo contactar al servicio de riesgo: %s", error)
            return []
        except Exception as error:  # pragma: no cover - fallo de entorno
            logger.warning("Fallo inesperado al consultar el servicio de riesgo: %s", error)
            return []

        return self._interpretar(cuerpo)

    @staticmethod
    def _interpretar(cuerpo: str) -> List[EvaluacionRiesgo]:
        """Convierte la respuesta JSON en evaluaciones de riesgo."""
        try:
            datos = json.loads(cuerpo)
        except ValueError:
            logger.warning("El servicio de riesgo devolvio una respuesta no valida.")
            return []

        if not isinstance(datos, list):
            logger.warning("El servicio de riesgo devolvio una forma inesperada.")
            return []

        evaluaciones = []
        for item in datos:
            if not isinstance(item, dict):
                continue

            usuario_id = item.get("userId")
            nivel = item.get("riskLevel")
            probabilidad = item.get("anxietyProbability")

            if not isinstance(usuario_id, int) or usuario_id <= 0:
                continue
            if nivel not in ("BAJO", "MEDIO", "ALTO"):
                continue
            if not isinstance(probabilidad, (int, float)):
                continue

            evaluaciones.append(
                EvaluacionRiesgo(
                    usuario_id=usuario_id,
                    probabilidad_ansiedad=float(probabilidad),
                    nivel_riesgo=nivel,
                    fecha=item.get("createdAt"),
                )
            )

        return evaluaciones

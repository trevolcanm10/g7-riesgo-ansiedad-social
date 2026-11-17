"""Cliente HTTP del microservicio de evaluacion de riesgo.

Consulta el endpoint agregado ``POST /risk-evaluations/summary/counts``, que
devuelve solo conteos por nivel de riesgo para un conjunto de estudiantes. No
existe la consulta del riesgo individual: el endpoint agregado es el unico
contrato que el panel utiliza.

El cliente nunca lanza excepciones: traduce cada fallo a un
``ResultadoRiesgo`` con su motivo, para que el panel pueda explicar por que no
hay correlacion en lugar de fallar en silencio.
"""

from __future__ import annotations

import json
import logging
import urllib.error
import urllib.request
from typing import List, Optional

from app.application.interfaces.evaluaciones_riesgo_port import IEvaluacionesRiesgoPort
from app.domain.entities.motivo_riesgo import MotivoRiesgo
from app.domain.entities.resultado_riesgo import ResultadoRiesgo

logger = logging.getLogger(__name__)

# Segundos de espera maxima antes de abandonar la consulta externa. El plan
# gratuito de Render duerme el servicio: en frio la primera respuesta puede
# tardar mas de 30 segundos.
TIMEOUT_SEGUNDOS = 45

# Niveles de riesgo que expone el microservicio de evaluacion.
NIVELES_RIESGO = ("BAJO", "MEDIO", "ALTO")


class EvaluacionesRiesgoClient(IEvaluacionesRiesgoPort):
    """Cliente del endpoint agregado de conteos por nivel de riesgo."""

    def __init__(self, url_base: Optional[str] = None, timeout: int = TIMEOUT_SEGUNDOS) -> None:
        self._url_base = (url_base or "").rstrip("/")
        self._timeout = timeout

    def contar_riesgos(self, usuario_ids: List[int], token: str) -> ResultadoRiesgo:
        """Pide el conteo por nivel de riesgo de los estudiantes indicados."""
        if not self._url_base:
            logger.warning("No hay RISK_EVALUATION_BASE_URL configurada.")
            return ResultadoRiesgo(motivo=MotivoRiesgo.NO_CONFIGURADO)
        if not usuario_ids:
            return ResultadoRiesgo(motivo=MotivoRiesgo.SIN_DATOS)
        if not token:
            logger.warning("No hay token para consultar el servicio de riesgo.")
            return ResultadoRiesgo(motivo=MotivoRiesgo.NO_AUTORIZADO)

        cuerpo = json.dumps({"userIds": [int(usuario_id) for usuario_id in usuario_ids]}).encode("utf-8")
        peticion = urllib.request.Request(
            f"{self._url_base}/risk-evaluations/summary/counts",
            data=cuerpo,
            method="POST",
        )
        peticion.add_header("Accept", "application/json")
        peticion.add_header("Content-Type", "application/json")
        peticion.add_header("Authorization", f"Bearer {token}")

        try:
            with urllib.request.urlopen(peticion, timeout=self._timeout) as respuesta:
                if respuesta.status != 200:
                    logger.warning("El servicio de riesgo respondio HTTP %s.", respuesta.status)
                    return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)
                texto = respuesta.read().decode("utf-8")
        except urllib.error.HTTPError as error:
            if error.code in (401, 403):
                logger.warning("El servicio de riesgo rechazo el token (HTTP %s).", error.code)
                return ResultadoRiesgo(motivo=MotivoRiesgo.NO_AUTORIZADO)
            logger.warning("El servicio de riesgo respondio HTTP %s.", error.code)
            return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)
        except urllib.error.URLError as error:
            logger.warning("No se pudo contactar al servicio de riesgo: %s", error)
            return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)
        except Exception as error:
            logger.warning("Fallo inesperado al consultar el servicio de riesgo: %s", error)
            return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)

        return self._interpretar(texto)

    @staticmethod
    def _interpretar(texto: str) -> ResultadoRiesgo:
        """Convierte la respuesta JSON del servicio en un ``ResultadoRiesgo``."""
        try:
            cuerpo = json.loads(texto)
        except (TypeError, ValueError):
            logger.warning("El servicio de riesgo devolvio una respuesta ilegible.")
            return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)
        if not isinstance(cuerpo, dict):
            logger.warning("El servicio de riesgo devolvio una respuesta con forma inesperada.")
            return ResultadoRiesgo(motivo=MotivoRiesgo.SERVICIO_NO_DISPONIBLE)

        if cuerpo.get("suprimido") is True:
            return ResultadoRiesgo(
                total=None,
                suprimido=True,
                conteos={},
                motivo=MotivoRiesgo.SUPRIMIDO_K5,
            )

        total = cuerpo.get("total")
        total_valido = total if isinstance(total, int) and not isinstance(total, bool) else None

        conteos_crudos = cuerpo.get("conteos")
        if not isinstance(conteos_crudos, dict):
            return ResultadoRiesgo(total=total_valido, motivo=MotivoRiesgo.SIN_DATOS)

        conteos: dict = {}
        for nivel in NIVELES_RIESGO:
            valor = conteos_crudos.get(nivel)
            if isinstance(valor, bool) or not isinstance(valor, int) or valor <= 0:
                continue
            conteos[nivel] = valor

        if not conteos:
            return ResultadoRiesgo(total=total_valido, motivo=MotivoRiesgo.SIN_DATOS)

        return ResultadoRiesgo(
            total=total_valido,
            suprimido=False,
            conteos=conteos,
            motivo=MotivoRiesgo.DISPONIBLE,
        )

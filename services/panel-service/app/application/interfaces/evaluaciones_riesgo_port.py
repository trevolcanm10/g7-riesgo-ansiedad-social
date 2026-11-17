"""Puerto de salida hacia el microservicio de evaluacion de riesgo.

REGLA DE AISLAMIENTO DE DATOS
------------------------------
El nivel de riesgo vive en el microservicio ``riskEvaluation``. Este puerto no
da acceso a su base de datos: solo permite pedir, para un conjunto de
estudiantes, el **conteo** por nivel de riesgo. Nunca se pide el riesgo
individual de un estudiante.

REGLA DE PRIVACIDAD k=5
-----------------------
El microservicio deevaluacion aplica la misma regla de privacidad que el
panel: si el grupo consultado tiene menos de cinco estudiantes, responde que el
dato esta suprimido y no devuelve conteos.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from typing import List

from app.domain.entities.resultado_riesgo import ResultadoRiesgo


class IEvaluacionesRiesgoPort(ABC):
    """Consulta de conteos por nivel de riesgo a un conjunto de estudiantes."""

    @abstractmethod
    def contar_riesgos(self, usuario_ids: List[int], token: str) -> ResultadoRiesgo:
        """Devuelve el conteo por nivel de riesgo de los estudiantes indicados.

        El ``token`` es el de la peticion en curso: se reenvia para que el
        microservicio de evaluacion valide identidad y rol.

        Nunca lanza excepciones: cualquier fallo se traduce a un
        ``ResultadoRiesgo`` con el motivo correspondiente.
        """

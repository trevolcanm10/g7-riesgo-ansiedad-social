"""Caso de uso: cruzar el nivel de riesgo con los perfiles de agrupamiento.

Responde la pregunta institucional: "de los estudiantes de cada perfil de
agrupamiento, cuantos estan en riesgo alto, medio y bajo".

REGLA DE AISLAMIENTO DE DATOS
------------------------------
El nivel de riesgo vive en el microservicio ``riskEvaluation``. Este caso de
uso no lee su base de datos: lo consulta por HTTP a traves del puerto
``IEvaluacionesRiesgoPort``, que solo admite el endpoint agregado de conteos.

REGLA DE PRIVACIDAD k=5
-----------------------
Las celdas con menos de cinco estudiantes se ocultan, igual que los grupos.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from app.application.interfaces.evaluaciones_riesgo_port import IEvaluacionesRiesgoPort
from app.domain.entities.motivo_riesgo import MotivoRiesgo
from app.domain.entities.perfil_cluster import Grupo, PerfilCluster
from app.domain.services.privacidad_k5 import MINIMO_GRUPO, filtrar_grupos


class ObtenerRiesgoPorPerfil:
    """Cruza los perfiles de agrupamiento con el nivel de riesgo."""

    def __init__(self, evaluaciones_riesgo: IEvaluacionesRiesgoPort) -> None:
        self._evaluaciones_riesgo = evaluaciones_riesgo

    def execute(
        self,
        perfiles: List[PerfilCluster],
        estudiantes_por_cluster: Dict[int, List[int]],
        token: Optional[str] = None,
    ) -> Tuple[List[PerfilCluster], int, MotivoRiesgo]:
        """Devuelve ``(perfiles_enriquecidos, celdas_omitidas, motivo)``.

        El motivo resume por que no hay correlacion: si el servicio de
        evaluacion no esta configurado, rechazo el token o no responde, el
        panel lo expone para que la interfaz lo explique.
        """
        if not perfiles or not estudiantes_por_cluster:
            return perfiles, 0, MotivoRiesgo.SIN_DATOS

        celdas_omitidas = 0
        enriquecidos: List[PerfilCluster] = []
        motivos: List[MotivoRiesgo] = []

        for perfil in perfiles:
            estudiantes = estudiantes_por_cluster.get(perfil.cluster, [])
            if not estudiantes:
                perfil.riesgo_disponible = False
                perfil.riesgo_motivo = MotivoRiesgo.SIN_DATOS.value
                motivos.append(MotivoRiesgo.SIN_DATOS)
                enriquecidos.append(perfil)
                continue

            resultado = self._evaluaciones_riesgo.contar_riesgos(sorted(set(estudiantes)), token or "")
            motivos.append(resultado.motivo)

            if resultado.motivo is not MotivoRiesgo.DISPONIBLE:
                perfil.riesgo_disponible = False
                perfil.riesgo_motivo = resultado.motivo.value
                enriquecidos.append(perfil)
                continue

            celdas_visibles = filtrar_grupos(
                [Grupo(etiqueta=nivel, n=n) for nivel, n in resultado.conteos.items()],
                MINIMO_GRUPO,
            )
            celdas_omitidas += celdas_visibles.omitidos
            perfil.riesgo = {grupo.etiqueta: grupo.n for grupo in celdas_visibles.grupos}
            perfil.riesgo_omitidos = celdas_visibles.omitidos
            perfil.riesgo_disponible = bool(celdas_visibles.grupos)
            perfil.riesgo_motivo = (
                MotivoRiesgo.DISPONIBLE.value
                if celdas_visibles.grupos
                else MotivoRiesgo.SUPRIMIDO_K5.value
            )
            enriquecidos.append(perfil)

        return enriquecidos, celdas_omitidas, self._motivo_global(motivos)

    @staticmethod
    def _motivo_global(motivos: List[MotivoRiesgo]) -> MotivoRiesgo:
        """Resume el motivo global a partir del motivo de cada perfil."""
        if not motivos:
            return MotivoRiesgo.SIN_DATOS
        if MotivoRiesgo.DISPONIBLE in motivos:
            return MotivoRiesgo.DISPONIBLE
        if len(set(motivos)) == 1:
            return motivos[0]
        return MotivoRiesgo.SIN_DATOS

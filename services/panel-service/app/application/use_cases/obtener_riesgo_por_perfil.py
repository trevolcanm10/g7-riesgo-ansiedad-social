"""Caso de uso: cruzar el nivel de riesgo con los perfiles de agrupamiento.

Responde la pregunta institucional: "de los estudiantes de cada perfil de
agrupamiento, cuantos estan en riesgo alto, medio y bajo".

REGLA DE AISLAMIENTO DE DATOS
------------------------------
El nivel de riesgo vive en el microservicio ``riskEvaluation``. Este caso de
uso no lee su base de datos: lo consulta por HTTP a traves del puerto
``IEvaluacionesRiesgoPort``.

REGLA DE PRIVACIDAD k=5
-----------------------
Las celdas con menos de cinco estudiantes se ocultan, igual que los grupos.
"""

from __future__ import annotations

from typing import Dict, List, Optional

from app.application.interfaces.evaluaciones_riesgo_port import IEvaluacionesRiesgoPort
from app.domain.entities.perfil_cluster import Grupo, PerfilCluster
from app.domain.services.privacidad_k5 import MINIMO_GRUPO, filtrar_grupos

# Niveles de riesgo que expone el microservicio de evaluacion.
NIVELES_RIESGO = ("BAJO", "MEDIO", "ALTO")


class ObtenerRiesgoPorPerfil:
    """Cruza los perfiles de agrupamiento con el nivel de riesgo de riesgo."""

    def __init__(self, evaluaciones_riesgo: IEvaluacionesRiesgoPort) -> None:
        self._evaluaciones_riesgo = evaluaciones_riesgo

    def execute(
        self,
        perfiles: List[PerfilCluster],
        estudiantes_por_cluster: Dict[int, List[int]],
    ) -> tuple:
        """Devuelve ``(perfiles_enriquecidos, celdas_omitidas)``.

        ``estudiantes_por_cluster`` asocia cada cluster con los identificadores
        de los estudiantes que lo tienen asignado. Los perfiles que ya superaron
        la regla k=5 llegan aqui; dentro de cada perfil tambien se ocultan las
        celdas de nivel de riesgo con menos de cinco estudiantes.
        """
        if not perfiles or not estudiantes_por_cluster:
            return perfiles, 0

        ids = sorted({e for lista in estudiantes_por_cluster.values() for e in lista})
        if not ids:
            return perfiles, 0

        # Si el servicio de riesgo no responde, la lista viene vacia y el
        # panel se muestra sin la correlacion de riesgo.
        evaluaciones = self._evaluaciones_riesgo.listar_evaluaciones(ids)
        if not evaluaciones:
            return perfiles, 0

        nivel_por_usuario = {e.usuario_id: e.nivel_riesgo for e in evaluaciones}

        celdas_omitidas = 0
        enriquecidos: List[PerfilCluster] = []

        for perfil in perfiles:
            estudiantes = estudiantes_por_cluster.get(perfil.cluster, [])
            conteo = {nivel: 0 for nivel in NIVELES_RIESGO}

            for usuario_id in estudiantes:
                nivel = nivel_por_usuario.get(usuario_id)
                if nivel in conteo:
                    conteo[nivel] += 1

            # Aplicamos k=5 tambien a las celdas internas del perfil. Una
            # celda con cero estudiantes no esta "oculta por privacidad",
            # simplemente no existe: no cuenta como omitida.
            celdas_visibles = filtrar_grupos(
                [
                    Grupo(etiqueta=nivel, n=n)
                    for nivel, n in conteo.items()
                    if n > 0
                ],
                MINIMO_GRUPO,
            )
            celdas_omitidas += celdas_visibles.omitidos

            perfil.riesgo = {grupo.etiqueta: grupo.n for grupo in celdas_visibles.grupos}
            perfil.riesgo_omitidos = celdas_visibles.omitidos
            perfil.riesgo_disponible = True
            enriquecidos.append(perfil)

        return enriquecidos, celdas_omitidas

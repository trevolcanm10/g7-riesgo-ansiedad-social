"""Caso de uso: obtener las estadisticas anonimizadas del panel.

Aplica la regla de privacidad k=5 a toda agrupacion antes de construir la
respuesta. Los grupos suprimidos no aparecen en ningun campo; solo se
informa cuantos fueron omitidos, para que el panel sea transparente con el
personal institucional.
"""

from __future__ import annotations

from typing import List, Optional

from app.application.interfaces.atencion_repository_port import IAtencionRepository
from app.application.interfaces.clustering_port import IClusteringPort
from app.application.use_cases.obtener_riesgo_por_perfil import ObtenerRiesgoPorPerfil
from app.domain.entities.perfil_cluster import Grupo, PerfilCluster
from app.domain.services.privacidad_k5 import MINIMO_GRUPO, filtrar_grupos, filtrar_perfiles

# Texto que acompana toda respuesta con resultados de IA. Es obligatorio por
# la regla de IA responsable: las estimaciones son orientativas y no son
# diagnosticos clinicos.
NOTA_IA = (
    "Las estimaciones son orientativas y no constituyen un diagnostico clinico. "
    "Los perfiles provienen de un dataset sintetico y no describen poblaciones reales."
)


class ObtenerEstadisticas:
    """Construye el conjunto de indicadores del panel."""

    def __init__(
        self,
        repository: IAtencionRepository,
        clustering: IClusteringPort,
        riesgo_por_perfil: Optional[ObtenerRiesgoPorPerfil] = None,
    ) -> None:
        self._repository = repository
        self._clustering = clustering
        self._riesgo_por_perfil = riesgo_por_perfil

    def execute(self, periodo: Optional[str] = None) -> dict:
        """Devuelve las estadisticas del periodo aplicando la regla k=5."""
        total_atenciones = self._repository.total_atencioness(periodo)

        por_tipo = self._grupos(self._repository.contar_por_dimension("tipo", periodo))
        por_modalidad = self._grupos(self._repository.contar_por_dimension("modalidad", periodo))
        por_estado = self._grupos(self._repository.contar_por_dimension("estado", periodo))
        por_periodo = self._grupos(self._repository.contar_por_dimension("periodo", periodo))

        # Perfiles de IA: el numero de estudiantes por cluster se recalcula
        # sobre el periodo solicitado, no sobre el conjunto de entrenamiento
        # del modelo. La regla k=5 se aplica sobre ese conteo real.
        conteo_clusters = self._repository.contar_por_cluster(periodo)
        perfiles_por_cluster = self._perfiles(conteo_clusters)

        # Correlacion con el nivel de riesgo publicado por el microservicio de
        # evaluacion. Se consulta por HTTP: este servicio no lee la base de
        # datos de ese servicio.
        celdas_riesgo_omitidas = 0
        riesgo_disponible = False
        if self._riesgo_por_perfil is not None and perfiles_por_cluster.perfiles:
            estudiantes_por_cluster = self._repository.listar_estudiantes_por_cluster(periodo)
            perfiles_por_cluster.perfiles, celdas_riesgo_omitidas = (
                self._riesgo_por_perfil.execute(
                    perfiles_por_cluster.perfiles, estudiantes_por_cluster
                )
            )
            riesgo_disponible = any(
                perfil.riesgo_disponible for perfil in perfiles_por_cluster.perfiles
            )

        omitidos = (
            por_tipo.omitidos
            + por_modalidad.omitidos
            + por_estado.omitidos
            + por_periodo.omitidos
            + perfiles_por_cluster.omitidos
            + celdas_riesgo_omitidas
        )

        return {
            "periodo": periodo,
            "total_atenciones": total_atenciones,
            "requieren_seguimiento": self._repository.contar_por_seguimiento(periodo),
            "por_tipo": [grupo.to_dict() for grupo in por_tipo.grupos],
            "por_modalidad": [grupo.to_dict() for grupo in por_modalidad.grupos],
            "por_estado": [grupo.to_dict() for grupo in por_estado.grupos],
            "por_periodo": [grupo.to_dict() for grupo in por_periodo.grupos],
            "perfiles_ia": [perfil.to_dict() for perfil in perfiles_por_cluster.perfiles],
            "grupos_omitidos_por_privacidad": omitidos,
            "minimo_grupo_publicable": MINIMO_GRUPO,
            "riesgo_disponible": riesgo_disponible,
            "nota_ia": NOTA_IA,
        }

    @staticmethod
    def _grupos(conteos) -> "object":
        """Convierte pares ``(etiqueta, n)`` en grupos y aplica k=5."""
        grupos = [Grupo(etiqueta=etiqueta, n=n) for etiqueta, n in conteos]
        return filtrar_grupos(grupos)

    def _perfiles(self, conteo_clusters) -> "object":
        """Cruza el conteo real por cluster con la descripcion del modelo.

        El porcentaje se calcula sobre los estudiantes con perfil asignado en
        el periodo consultado, no sobre el total de atenciones (que incluye
        las registradas sin indicadores).
        """
        descripciones = {perfil.cluster: perfil for perfil in self._clustering.perfiles_disponibles()}

        con_perfil = sum(n for cluster, n in conteo_clusters if cluster is not None)
        base = max(con_perfil, 1)

        perfiles: List[PerfilCluster] = []
        for cluster, n in conteo_clusters:
            if cluster is None:
                # Atenciones sin indicadores: no se exponen como perfil de IA.
                continue
            base_perfil = descripciones.get(cluster)
            perfiles.append(
                PerfilCluster(
                    cluster=cluster,
                    n=n,
                    porcentaje=round(n / base * 100, 1),
                    descripcion=base_perfil.descripcion if base_perfil else "Perfil orientativo.",
                    medias=dict(base_perfil.medias) if base_perfil else {},
                    nivel_orientativo=base_perfil.nivel_orientativo if base_perfil else "no_clasificado",
                )
            )

        return filtrar_perfiles(perfiles)

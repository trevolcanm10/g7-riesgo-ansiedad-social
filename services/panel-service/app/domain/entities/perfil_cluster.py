"""Entidad de dominio: perfil de agrupamiento y series anonimizadas.

Representa la salida del modelo de clustering (perfiles de estudiante) y los
agrupados estadisticos que consume el panel.

REGLA DE PRIVACIDAD
-------------------
Toda serie o perfil que se devuelva al exterior debe pasar por
``app.domain.services.privacidad_k5``. Ningun grupo con menos de
``MINIMO_GRUPO`` estudiantes puede salir del dominio.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import List, Optional


@dataclass
class PerfilCluster:
    """Perfil orientativo de un grupo de estudiantes.

    Proviene del modelo de agrupamiento. Es una estimacion orientativa y no
    un diagnostico clinico.
    """

    cluster: int
    n: int
    descripcion: str
    medias: dict = field(default_factory=dict)
    nivel_orientativo: str = "no_clasificado"
    # Proporcion de estudiantes del perfil sobre el total del periodo, en
    # porcentaje. Se calcula sobre los datos reales del panel, no sobre el
    # conjunto de entrenamiento del modelo.
    porcentaje: float = 0.0
    # Conteo por nivel de riesgo dentro del perfil. Se obtiene por HTTP
    # consultando al microservicio de evaluacion de riesgo. Las celdas con
    # menos de cinco estudiantes se omiten por la regla de privacidad.
    riesgo: dict = field(default_factory=dict)
    # Numero de celdas de nivel de riesgo ocultas por la regla k=5.
    riesgo_omitidos: int = 0
    # Indica si el servicio de evaluacion de riesgo respondio. Si es False,
    # el perfil se muestra sin la correlacion de riesgo.
    riesgo_disponible: bool = False

    def to_dict(self) -> dict:
        """Serializa el perfil para la capa de presentacion."""
        return {
            "cluster": self.cluster,
            "n": self.n,
            "porcentaje": self.porcentaje,
            "descripcion": self.descripcion,
            "medias": dict(self.medias),
            "nivel_orientativo": self.nivel_orientativo,
            "riesgo": dict(self.riesgo),
            "riesgo_omitidos": self.riesgo_omitidos,
            "riesgo_disponible": self.riesgo_disponible,
        }


@dataclass
class Grupo:
    """Agrupado estadistico por una dimension (tipo, modalidad, periodo).

    ``n`` es el numero de estudiantes que compone el grupo y determina si el
    grupo puede mostrarse (regla k=5).
    """

    etiqueta: str
    n: int
    extras: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        """Serializa el grupo para la capa de presentacion."""
        payload = {"etiqueta": self.etiqueta, "n": self.n}
        payload.update(self.extras)
        return payload


@dataclass
class ResultadoPrivacidad:
    """Resultado de aplicar la regla k=5 a un conjunto de grupos.

    ``omitidos`` es el numero de grupos ocultos. Se publica para que el
    panel sea transparente con el personal institucional sin revelar el
    contenido de los grupos suprimidos.
    """

    grupos: List[Grupo] = field(default_factory=list)
    omitidos: int = 0

    @property
    def total_visible(self) -> int:
        """Suma de estudiantes en los grupos visibles."""
        return sum(grupo.n for grupo in self.grupos)


@dataclass
class ResultadoPerfilesPrivacidad:
    """Resultado de aplicar la regla k=5 a los perfiles de agrupamiento.

    Se separa de :class:`ResultadoPrivacidad` porque los perfiles se exponen
    con su propia forma (descripcion, medias, nivel) y no como grupos
    estadisticos simples.
    """

    perfiles: List[PerfilCluster] = field(default_factory=list)
    omitidos: int = 0

    @property
    def total_visible(self) -> int:
        """Suma de estudiantes en los perfiles visibles."""
        return sum(perfil.n for perfil in self.perfiles)

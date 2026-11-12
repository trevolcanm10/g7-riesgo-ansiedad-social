"""Adaptador de agrupamiento (clustering).

Carga el artefacto ``modelo_clustering.joblib``, que es un
``Pipeline(StandardScaler, KMeans)``. El escalador viaja dentro del pipeline
a proposito: K-Means depende de la escala y aplicar el modelo sobre datos
crudos produce resultados invalidos.

Los perfiles que devuelve son estimaciones orientativas sobre un dataset
sintetico. No son diagnosticos clinicos.
"""

from __future__ import annotations

import json
import logging
import os
from typing import List, Optional

import joblib
import numpy as np

from app.application.interfaces.clustering_port import IClusteringPort
from app.domain.entities.perfil_cluster import PerfilCluster

logger = logging.getLogger(__name__)

# Orden canonico de features. Coincide con el script de entrenamiento
# (ml/train_clustering.py) y con el contrato de evaluacion de riesgo.
FEATURES = (
    "PHQ9",
    "GAD7",
    "OnlineStress",
    "FinancialStress",
    "ExerciseFreq",
    "SocialActivity",
    "SleepHours",
)

# Equivalencia entre las claves del contrato de la API y las columnas del
# dataset con las que se entreno el modelo.
MAPEO_INDICADORES = {
    "phq9": "PHQ9",
    "gad7": "GAD7",
    "online_stress": "OnlineStress",
    "financial_stress": "FinancialStress",
    "exercise_freq": "ExerciseFreq",
    "social_activity": "SocialActivity",
    "sleep_hours": "SleepHours",
}

# Mensaje que se expone al panel cuando el modelo no esta disponible.
SIN_MODELO = (
    "El modelo de agrupamiento no esta disponible. "
    "Los perfiles de IA no pueden mostrarse en este momento."
)


class ScikitClusteringAdapter(IClusteringPort):
    """Implementa el puerto de clustering con el artefacto de scikit-learn."""

    def __init__(self, directorio: Optional[str] = None) -> None:
        base = directorio or os.path.join(os.path.dirname(__file__), "artifacts")
        self._ruta_modelo = os.path.join(base, "modelo_clustering.joblib")
        self._ruta_perfiles = os.path.join(base, "perfiles_clusteres.json")

        self._modelo = None
        self._perfiles: List[PerfilCluster] = []
        self._disponible = False

        self._cargar()

    def _cargar(self) -> None:
        """Carga el modelo y los perfiles; si falta, el servicio degrada."""
        try:
            if not os.path.exists(self._ruta_modelo):
                logger.warning("No se encontro el modelo en %s", self._ruta_modelo)
                return

            self._modelo = joblib.load(self._ruta_modelo)

            if os.path.exists(self._ruta_perfiles):
                with open(self._ruta_perfiles, "r", encoding="utf-8") as archivo:
                    datos = json.load(archivo)
                self._perfiles = [
                    PerfilCluster(
                        cluster=item["cluster"],
                        n=int(item["n"]),
                        descripcion=item["descripcion"],
                        medias=item.get("medias", {}),
                        nivel_orientativo=item.get("nivel_orientativo", "no_clasificado"),
                    )
                    for item in datos.get("perfiles", [])
                ]

            self._disponible = True
        except Exception as error:  # pragma: no cover - fallo de entorno
            logger.error("No se pudo cargar el modelo de agrupamiento: %s", error)
            self._modelo = None
            self._disponible = False

    @property
    def disponible(self) -> bool:
        """Indica si el modelo pudo cargarse."""
        return self._disponible

    def asignar_cluster(self, indicadores: dict) -> Optional[int]:
        """Devuelve el cluster del estudiante segun sus indicadores.

        Es una estimacion orientativa, no un diagnostico clinico.
        """
        if not self._disponible or self._modelo is None:
            return None

        valores = self._construir_vector(indicadores)
        if valores is None:
            return None

        try:
            etiqueta = self._modelo.predict(valores.reshape(1, -1))[0]
            return int(etiqueta)
        except Exception as error:  # pragma: no cover - fallo de entorno
            logger.error("Fallo la inferencia del modelo de agrupamiento: %s", error)
            return None

    def perfiles_disponibles(self) -> List[PerfilCluster]:
        """Devuelve la descripcion de cada perfil connu por el modelo."""
        return list(self._perfiles)

    @staticmethod
    def _construir_vector(indicadores: dict) -> Optional[np.ndarray]:
        """Construye el vector de features en el orden canonico.

        Devuelve ``None`` si falta alguna de las siete variables: el modelo
        no admite inferencia con datos incompletos.
        """
        valores = []
        for clave, columna in MAPEO_INDICADORES.items():
            valor = indicadores.get(clave)
            if valor is None:
                return None
            try:
                valores.append(float(valor))
            except (TypeError, ValueError):
                return None

        return np.asarray(valores, dtype=float)

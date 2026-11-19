from abc import ABC, abstractmethod
from typing import Mapping


class WeeklyClassifier(ABC):
    """Puerto de clasificador semanal de carga académica."""

    @abstractmethod
    def classify_week(self, indicators: Mapping[str, float]) -> dict:
        """Clasifica la carga semanal. Devuelve nivel y probabilidad."""
from abc import ABC, abstractmethod
from typing import Tuple


class IMLClassifier(ABC):
    @property
    def model_status(self) -> str:
        """Identifica si se usa el modelo entrenado o la línea base de respaldo."""
        return "unknown"

    @abstractmethod
    def predict(self, text: str) -> Tuple[str, str]:
        """
        Retorna (tema_sugerido, prioridad_sugerida)
        """
        pass

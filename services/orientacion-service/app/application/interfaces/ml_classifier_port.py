from abc import ABC, abstractmethod
from typing import Tuple

class IMLClassifier(ABC):
    @abstractmethod
    def predict(self, text: str) -> Tuple[str, str]:
        """
        Retorna (tema_sugerido, prioridad_sugerida)
        """
        pass

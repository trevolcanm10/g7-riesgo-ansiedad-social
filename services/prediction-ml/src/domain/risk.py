from abc import ABC, abstractmethod
from math import isfinite
from typing import Mapping


class PredictionError(Exception):
    """The predictor could not produce a valid risk probability."""


class ModelsUnavailableError(PredictionError):
    """The required ensemble is unavailable."""


class RiskPredictor(ABC):
    @abstractmethod
    def predict_probability(self, indicators: Mapping[str, float]) -> float:
        """Return the probability of anxiety risk (class 0)."""


def categorize_risk(probability: float) -> str:
    if not isfinite(probability) or not 0 <= probability <= 1:
        raise PredictionError("Probabilidad de riesgo inválida")
    if probability < 0.35:
        return "BAJO"
    if probability <= 0.70:
        return "MEDIO"
    return "ALTO"

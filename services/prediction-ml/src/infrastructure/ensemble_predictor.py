import logging
from pathlib import Path
from typing import Mapping

import joblib
import numpy as np
import pandas as pd

from src.domain.risk import ModelsUnavailableError, PredictionError, RiskPredictor

FEATURES = (
    "PHQ9", "GAD7", "OnlineStress", "FinancialStress",
    "ExerciseFreq", "SocialActivity", "SleepHours",
)
INDICATORS = (
    "phq9_score", "gad7_score", "online_stress", "financial_stress",
    "exercise_freq", "social_activity", "sleep_hours",
)
MODEL_FILES = (
    "catboost_weighted_model.pkl", "knn_model.pkl", "lightgbm_model.pkl",
    "random_forest_model.pkl", "xgboost_weighted_model.pkl",
)
logger = logging.getLogger(__name__)


class EnsemblePredictor(RiskPredictor):
    def __init__(self, models_dir: Path | None = None):
        directory = models_dir if models_dir is not None else Path(__file__).parent / "models"
        self._models = []
        try:
            for filename in MODEL_FILES:
                # Only load these five trusted repository artifacts; never a client path.
                model = joblib.load(directory / filename)
                classes = list(model.classes_)
                if len(classes) != 2 or set(classes) != {0, 1}:
                    raise ValueError(f"{filename}: clases incompatibles: {classes}")
                names = None
                for attribute in ("feature_names_in_", "feature_names_", "feature_name_"):
                    value = getattr(model, attribute, None)
                    if value is not None and len(value):
                        names = list(value)
                        break
                if names is not None and names != list(FEATURES):
                    raise ValueError(f"{filename}: orden de features incompatible: {names}")
                count = getattr(model, "n_features_in_", None)
                # CatBoost's loaded artifact reports 0; its seven names verify the contract.
                if count not in (None, 0, len(FEATURES)) or (not count and names is None):
                    raise ValueError(f"{filename}: número de features incompatible: {count}")
                if names is None:
                    logger.warning("%s no conserva nombres; se verifica el número y se aplica el orden contractual", filename)
                if not callable(getattr(model, "predict_proba", None)):
                    raise ValueError(f"{filename}: predict_proba no disponible")
                self._models.append((model, classes.index(0), names is not None))
        except Exception as exc:
            self._models.clear()
            raise ModelsUnavailableError("No se pudieron cargar los cinco modelos") from exc

    @property
    def models_loaded(self) -> int:
        return len(self._models)

    def predict_probability(self, indicators: Mapping[str, float]) -> float:
        if self.models_loaded != len(MODEL_FILES):
            raise ModelsUnavailableError("El ensamble completo no está disponible")
        try:
            frame = pd.DataFrame([[indicators[key] for key in INDICATORS]], columns=FEATURES)
            probabilities = []
            for model, risk_index, has_names in self._models:
                # KNN was fitted without feature names; preserve the identical column order.
                data = frame if has_names else frame.to_numpy()
                output = np.asarray(model.predict_proba(data), dtype=float)
                if (output.shape != (1, 2) or not np.isfinite(output).all()
                        or (output < 0).any() or (output > 1).any()
                        or not np.isclose(output.sum(), 1, atol=1e-6)):
                    raise ValueError("predict_proba devolvió probabilidades inválidas")
                probabilities.append(float(output[0, risk_index]))
            return float(np.mean(probabilities))
        except Exception as exc:
            raise PredictionError("Falló la inferencia del ensamble") from exc

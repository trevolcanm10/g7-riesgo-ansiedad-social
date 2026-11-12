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
MODEL_FILE = "xgboost_weighted_model.pkl"


class XGBoostPredictor(RiskPredictor):
    def __init__(self, models_dir: Path | None = None):
        directory = models_dir if models_dir is not None else Path(__file__).parent / "models"
        try:
            model = joblib.load(directory / MODEL_FILE)
            classes = list(model.classes_)
            if len(classes) != 2 or set(classes) != {0, 1}:
                raise ValueError("Clases incompatibles")
            if getattr(model, "n_features_in_", None) != len(FEATURES):
                raise ValueError("Número de variables incompatible")
            if list(model.feature_names_in_) != list(FEATURES):
                raise ValueError("Orden de variables incompatible")
            if not callable(getattr(model, "predict_proba", None)):
                raise ValueError("predict_proba no disponible")
            self._model = model
            self._risk_index = classes.index(0)
        except Exception as exc:
            raise ModelsUnavailableError("No se pudo cargar el modelo XGBoost") from exc

    @property
    def models_loaded(self) -> int:
        return 1

    def predict_probability(self, indicators: Mapping[str, float]) -> float:
        try:
            frame = pd.DataFrame([[indicators[key] for key in INDICATORS]], columns=FEATURES)
            output = np.asarray(self._model.predict_proba(frame), dtype=float)
            if (output.shape != (1, 2) or not np.isfinite(output).all()
                    or (output < 0).any() or (output > 1).any()
                    or not np.isclose(output.sum(), 1, atol=1e-6)):
                raise ValueError("predict_proba devolvió probabilidades inválidas")
            return float(output[0, self._risk_index])
        except Exception as exc:
            raise PredictionError("Falló la inferencia de XGBoost") from exc

    def explain_risk(self, indicators: Mapping[str, float], probability: float) -> dict:
        # For binary XGBoost, raw Tree SHAP explains the log-odds of class 1.
        # Class 0 is risk, so negate both base and contributions. Check the
        # reconstructed class-0 probability against the active prediction.
        import shap

        frame = pd.DataFrame([[indicators[key] for key in INDICATORS]], columns=FEATURES)
        explanation = shap.TreeExplainer(self._model, model_output="raw")(frame)
        values = np.asarray(explanation.values, dtype=float)
        base = np.asarray(explanation.base_values, dtype=float)
        if values.shape != (1, len(FEATURES)) or base.size != 1:
            raise ValueError("Forma SHAP incompatible")
        risk_values = -values[0]
        risk_base = -float(base.item())
        if not np.isfinite(risk_values).all() or not np.isfinite(risk_base):
            raise ValueError("Contribuciones SHAP inválidas")
        margin = risk_base + float(risk_values.sum())
        reconstructed = float(1 / (1 + np.exp(-margin)))
        if not np.isclose(reconstructed, probability, atol=1e-5, rtol=0):
            raise ValueError("SHAP no explica la probabilidad de clase 0")
        ranked = sorted(range(len(FEATURES)), key=lambda i: (-abs(risk_values[i]), i))[:3]
        return {
            "estado": "disponible",
            "escala": "log_odds_riesgo_clase_0",
            "factores": [
                {
                    "nombre": FEATURES[i],
                    "valor": float(risk_values[i]),
                    "direccion": "aumenta" if risk_values[i] > 0 else "disminuye" if risk_values[i] < 0 else "neutra",
                }
                for i in ranked
            ],
        }

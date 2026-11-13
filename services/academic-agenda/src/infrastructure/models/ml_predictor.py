import json

from pathlib import Path
from typing import Mapping, Optional

import joblib
import numpy as np
import pandas as pd

from ...domain.errors import ModelsUnavailableError, PredictionError
from ...domain.rules.weekly_classification import WeeklyClassifier


class MlWeeklyPredictor(WeeklyClassifier):
    """Cargador y predictor del modelo semanal de carga académica.

    Si el artefacto .joblib no está presente, informa que el predictor no
    está disponible sin bloquear el CRUD de actividades.
    """

    MODEL_FILE = "modelo_carga_academica.joblib"

    def __init__(self, models_dir: Path | None = None) -> None:
        directory = (
            models_dir if models_dir is not None
            else Path(__file__).resolve().parent.parent / "models"
        )
        contract_path = directory / "contrato_modelo_agenda.json"
        model_path = directory / self.MODEL_FILE

        self._contract = {}
        if contract_path.exists():
            with open(contract_path, encoding="utf-8") as fh:
                self._contract = json.load(fh)
        self._features = list(self._contract.get("features", []))
        self._target = list(self._contract.get("target", []))

        self._model = None
        self._available = False
        self._load_error = None
        try:
            if not model_path.exists():
                raise FileNotFoundError(f"Artefacto no encontrado: {model_path}")
            model = joblib.load(model_path)
            if not callable(getattr(model, "predict", None)):
                raise ValueError("El modelo no tiene método predict")
            self._model = model
            self._available = True
        except Exception as exc:
            self._model = None
            self._available = False
            self._load_error = exc

    @property
    def is_available(self) -> bool:
        return self._available

    @property
    def load_error(self) -> Optional[str]:
        return str(self._load_error) if not self._available else None

    @property
    def feature_names(self) -> list[str]:
        return list(self._features)

    @property
    def target_names(self) -> list[str]:
        return list(self._target)

    def _validate_features(self, indicators: Mapping[str, float]) -> None:
        missing = [f for f in self._features if f not in indicators]
        extra = [k for k in indicators if k not in self._features]
        if missing:
            raise ValueError(
                "Faltan las siguientes características del contrato: "
                + ", ".join(missing)
            )
        if extra:
            raise ValueError(
                "Características no reconocidas por el contrato: "
                + ", ".join(extra)
            )

    def _frame(self, indicators: Mapping[str, float]) -> pd.DataFrame:
        self._validate_features(indicators)
        return pd.DataFrame(
            [[indicators[f] for f in self._features]], columns=self._features
        )

    def predict(self, indicators: Mapping[str, float]) -> str:
        """Devuelve el nivel BAJO/MODERADO/ALTO sin reentrenar."""
        if not self._available or self._model is None:
            raise ModelsUnavailableError(
                "Predictor de carga semanal no disponible (falta el modelo .joblib)"
            )
        try:
            frame = self._frame(indicators)
            level = str(self._model.predict(frame)[0]).upper()
            if level not in self._target:
                raise ValueError(f"Nivel inesperado del modelo: {level}")
            return level
        except Exception as exc:
            raise PredictionError(f"Falló la inferencia predict: {exc}") from exc

    def predict_proba(self, indicators: Mapping[str, float]) -> dict[str, float]:
        """Devuelve un diccionario {nivel: probabilidad} para los 3 clases."""
        if not self._available or self._model is None:
            raise ModelsUnavailableError(
                "Predictor de carga semanal no disponible (falta el modelo .joblib)"
            )
        try:
            frame = self._frame(indicators)
            proba = np.asarray(self._model.predict_proba(frame), dtype=float)
            if proba.ndim != 2 or proba.shape[1] != len(self._target):
                raise ValueError("Probabilidades inválidas")
            if not np.isfinite(proba).all():
                raise ValueError("Probabilidades inválidas")
            return {
                str(level).upper(): float(p)
                for level, p in zip(self._target, proba[0])
            }
        except Exception as exc:
            raise PredictionError(f"Falló la inferencia predict_proba: {exc}") from exc

    def classify_week(self, indicators: Mapping[str, float]) -> dict:
        if not self._available or self._model is None:
            raise ModelsUnavailableError(
                "Predictor de carga semanal no disponible (falta el modelo .joblib)"
            )
        try:
            level = self.predict(indicators)
            proba = self.predict_proba(indicators)
            return {
                "nivel_carga": level,
                "probabilidad_nivel": round(proba[level], 6),
                "probabilidades": proba,
                "modelo": "clasificador_semanal",
            }
        except Exception as exc:
            raise PredictionError(f"Falló la inferencia semanal: {exc}") from exc

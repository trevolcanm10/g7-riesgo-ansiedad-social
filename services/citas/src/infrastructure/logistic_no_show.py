import json
import math
from pathlib import Path

from src.domain.ports import NoShowPredictor

_SUPPORTED = {"lead_log", "same_day", "prior_no_shows"}


class LogisticNoShowPredictor(NoShowPredictor):
    """Regresión logística calibrada (Platt) exportada por ml/train_no_show.py.

    Se evalúa en Python puro (sin scikit-learn). Usa solo anticipación e
    inasistencias previas; ignora prioridad y cualquier dato clínico o personal.
    Orientativo: solo para decidir recordatorios.
    """

    def __init__(self, artifact_path: str | Path):
        art = json.loads(Path(artifact_path).read_text(encoding="utf-8"))
        features = art["features"]
        if set(features) != _SUPPORTED or len(art["weights"]) != len(features):
            raise ValueError("Artefacto del modelo con variables no soportadas")
        self.MODEL = art["name"]
        self._features = features
        self._weights = art["weights"]
        self._means = art["feature_means"]
        self._labels = art["labels"]
        self._intercept = art["intercept"]
        self._a, self._b = art["platt"]["a"], art["platt"]["b"]
        self._cap_prior = art["caps"]["prior_no_shows"]
        self._cap_lead = art["caps"]["lead_days"]

    def _vector(self, features: dict) -> dict:
        # El entrenamiento usa días calendario enteros; aquí se trunca a días enteros.
        lead = min(int(max(features["lead_days"], 0)), self._cap_lead)
        return {
            "lead_log": math.log1p(lead),
            "same_day": 1.0 if lead == 0 else 0.0,
            "prior_no_shows": float(min(features["prior_no_shows"], self._cap_prior)),
        }

    def predict(self, features):
        x = self._vector(features)
        z = self._intercept + sum(w * x[f] for f, w in zip(self._features, self._weights))
        p = 1.0 / (1.0 + math.exp(-(self._a * z + self._b)))
        factors = []
        for f, w, mean in zip(self._features, self._weights, self._means):
            # Aporte respecto al promedio de entrenamiento (en escala logit calibrada).
            if self._a * w * (x[f] - mean) > 0.05:
                factors.append(self._labels[f])
        return {"probability": round(min(max(p, 0.01), 0.95), 3),
                "factors": factors, "model": self.MODEL}

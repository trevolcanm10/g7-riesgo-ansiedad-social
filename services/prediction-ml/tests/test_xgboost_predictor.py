import unittest
import json
from pathlib import Path
from unittest.mock import patch

import numpy as np

from src.domain.risk import ModelsUnavailableError, PredictionError
from src.application.predict_risk import PredictRiskUseCase
from src.infrastructure.fallback_report_generator import FallbackReportGenerator
from src.infrastructure.xgboost_predictor import XGBoostPredictor, FEATURES, MODEL_FILE
from src.presentation.http import create_http_app
PAYLOAD = json.loads((Path(__file__).resolve().parents[1] / "example.json").read_text())


class FakeModel:
    classes_ = np.array([1, 0])
    n_features_in_ = 7
    feature_names_in_ = np.array(FEATURES)

    def predict_proba(self, frame):
        assert list(frame.columns) == list(FEATURES)
        assert frame.iloc[0].tolist() == [8, 6, 6, 5, 3, 6, 7.5]
        return [[0.2, 0.8]]


class XGBoostPredictorTests(unittest.TestCase):
    def test_uses_only_xgboost_and_class_zero_probability(self):
        with patch("src.infrastructure.xgboost_predictor.joblib.load", return_value=FakeModel()) as load:
            predictor = XGBoostPredictor()
        self.assertEqual(load.call_count, 1)
        self.assertEqual(load.call_args.args[0].name, MODEL_FILE)
        self.assertEqual(predictor.models_loaded, 1)
        self.assertAlmostEqual(predictor.predict_probability(PAYLOAD), 0.8)

    def test_rejects_incompatible_model_or_missing_file(self):
        model = FakeModel()
        model.feature_names_in_ = np.array(list(reversed(FEATURES)))
        with patch("src.infrastructure.xgboost_predictor.joblib.load", return_value=model):
            with self.assertRaises(ModelsUnavailableError):
                XGBoostPredictor()
        with patch("src.infrastructure.xgboost_predictor.joblib.load", side_effect=OSError("missing")):
            with self.assertRaises(ModelsUnavailableError):
                XGBoostPredictor()

    def test_rejects_invalid_probability(self):
        model = FakeModel()
        model.predict_proba = lambda frame: [[float("nan"), 0.5]]
        with patch("src.infrastructure.xgboost_predictor.joblib.load", return_value=model):
            predictor = XGBoostPredictor()
        with self.assertRaises(PredictionError):
            predictor.predict_probability(PAYLOAD)

    def test_current_artifact_contract_and_inference(self):
        predictor = XGBoostPredictor()
        probability = predictor.predict_probability(PAYLOAD)
        self.assertGreaterEqual(probability, 0)
        self.assertLessEqual(probability, 1)
        client = create_http_app(
            PredictRiskUseCase(predictor, FallbackReportGenerator()),
            predictor.models_loaded,
        ).test_client()
        self.assertEqual(client.get("/health").status_code, 200)
        response = client.post("/predict", json=PAYLOAD)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(response.json),
            {"nivel_riesgo", "probabilidad_ansiedad", "explicacion", "reporte_ia", "explicacion_shap"},
        )
        self.assertAlmostEqual(response.json["probabilidad_ansiedad"], probability)
        factors = response.json["explicacion_shap"]["factores"]
        self.assertEqual(response.json["explicacion_shap"]["escala"], "log_odds_riesgo_clase_0")
        self.assertEqual(len(factors), 3)
        self.assertEqual([abs(f["valor"]) for f in factors], sorted(
            [abs(f["valor"]) for f in factors], reverse=True))
        self.assertEqual(len({f["nombre"] for f in factors}), 3)
        for factor in factors:
            self.assertIn(factor["nombre"], FEATURES)
            self.assertEqual(factor["direccion"], "aumenta" if factor["valor"] > 0 else "disminuye" if factor["valor"] < 0 else "neutra")
        with self.assertRaisesRegex(ValueError, "clase 0"):
            predictor.explain_risk(PAYLOAD, 1 - probability)

    def test_shap_failure_keeps_prediction_and_http_contract(self):
        predictor = XGBoostPredictor()
        with patch.object(predictor, "explain_risk", side_effect=RuntimeError("SHAP failed")):
            client = create_http_app(
                PredictRiskUseCase(predictor, FallbackReportGenerator()), 1,
            ).test_client()
            response = client.post("/predict", json=PAYLOAD)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["explicacion_shap"], {
            "estado": "no_disponible", "escala": "log_odds_riesgo_clase_0", "factores": [],
        })


if __name__ == "__main__":
    unittest.main()

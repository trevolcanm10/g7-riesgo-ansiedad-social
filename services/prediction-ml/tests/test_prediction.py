import json
from pathlib import Path
import unittest
from unittest.mock import patch

from src.application.predict_risk import PredictRiskUseCase
from src.infrastructure.fallback_report_generator import FallbackReportGenerator
from src.domain.risk import PredictionError, ModelsUnavailableError, RiskPredictor, categorize_risk
from src.presentation.http import create_http_app
from src.presentation.validation import RANGES, validate_indicators

PAYLOAD = json.loads((Path(__file__).resolve().parents[1] / "example.json").read_text())


class FakePredictor(RiskPredictor):
    def __init__(self, probability=0.8, error=None):
        self.probability = probability
        self.error = error
        self.calls = 0

    def predict_probability(self, indicators):
        self.calls += 1
        if self.error:
            raise self.error
        return self.probability


class PredictionTests(unittest.TestCase):
    def test_categories_and_boundaries(self):
        for probability, expected in [(0, "BAJO"), (.3499, "BAJO"), (.35, "MEDIO"),
                                      (.5, "MEDIO"), (.70, "MEDIO"), (.7001, "ALTO"), (1, "ALTO")]:
            with self.subTest(probability=probability):
                self.assertEqual(categorize_risk(probability), expected)

    def test_invalid_probability(self):
        for value in [-.1, 1.1, float("nan"), float("inf")]:
            with self.assertRaises(PredictionError):
                categorize_risk(value)

    def test_use_case_depends_on_port(self):
        fake = FakePredictor()
        result = PredictRiskUseCase(fake, FallbackReportGenerator()).execute(PAYLOAD)
        self.assertEqual(result["nivel_riesgo"], "ALTO")
        self.assertEqual(result["probabilidad_ansiedad"], .8)
        self.assertEqual(fake.calls, 1)

    def test_every_required_field_and_range(self):
        for name, (low, high) in RANGES.items():
            with self.subTest(field=name):
                missing = dict(PAYLOAD)
                del missing[name]
                with self.assertRaisesRegex(ValueError, name):
                    validate_indicators(missing)
                for value in [low - 1, high + 1, "5", True, None, float("nan"), float("inf")]:
                    with self.assertRaisesRegex(ValueError, name):
                        validate_indicators({**PAYLOAD, name: value})
                for value in [low, high]:
                    validate_indicators({**PAYLOAD, name: value})

    def test_http_valid_and_invalid(self):
        fake = FakePredictor()
        client = create_http_app(PredictRiskUseCase(fake, FallbackReportGenerator()), 5).test_client()
        self.assertEqual(client.get("/health").json["models_loaded"], 5)
        response = client.post("/predict", json=PAYLOAD)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["nivel_riesgo"], "ALTO")
        invalid_payloads = [[], None, {}, {**PAYLOAD, "gpa": 9}]
        for payload in invalid_payloads:
            self.assertEqual(client.post("/predict", data=json.dumps(payload), content_type="application/json").status_code, 400)
        self.assertEqual(client.post("/predict", data="{", content_type="application/json").status_code, 400)
        self.assertEqual(client.post("/predict", data="hello").status_code, 400)
        self.assertEqual(fake.calls, 1)

    def test_unavailable_and_failed_inference(self):
        client = create_http_app(None, 0).test_client()
        self.assertEqual(client.get("/health").status_code, 503)
        self.assertEqual(client.post("/predict", json=PAYLOAD).status_code, 503)
        for error, status in [(PredictionError("private details"), 500), (ModelsUnavailableError("private details"), 503)]:
            client = create_http_app(PredictRiskUseCase(FakePredictor(error=error), FallbackReportGenerator()), 5).test_client()
            response = client.post("/predict", json=PAYLOAD)
            self.assertEqual(response.status_code, status)
            self.assertNotIn("private details", response.get_data(as_text=True))


class EnsembleTests(unittest.TestCase):
    def test_feature_order_reversed_classes_and_equal_weights(self):
        import numpy as np
        from src.infrastructure.ensemble_predictor import EnsemblePredictor, FEATURES

        class Model:
            classes_ = np.array([1, 0])
            n_features_in_ = 7
            feature_names_in_ = np.array(FEATURES)

            def __init__(self, probability):
                self.probability = probability

            def predict_proba(self, frame):
                self_columns = list(frame.columns)
                if self_columns != list(FEATURES) or frame.iloc[0].tolist() != [8, 6, 6, 5, 3, 6, 7.5]:
                    raise AssertionError("Incorrect feature contract")
                return [[1 - self.probability, self.probability]]

        with patch("src.infrastructure.ensemble_predictor.joblib.load", side_effect=[Model(p) for p in [.1, .2, .3, .4, .5]]) as load:
            predictor = EnsemblePredictor()
        self.assertEqual(load.call_count, 5)
        self.assertAlmostEqual(predictor.predict_probability(PAYLOAD), .3)

    def test_loading_failure_has_no_fallback(self):
        from src.infrastructure.ensemble_predictor import EnsemblePredictor
        with patch("src.infrastructure.ensemble_predictor.joblib.load", side_effect=OSError("missing")):
            with self.assertRaises(ModelsUnavailableError):
                EnsemblePredictor()


if __name__ == "__main__":
    unittest.main()

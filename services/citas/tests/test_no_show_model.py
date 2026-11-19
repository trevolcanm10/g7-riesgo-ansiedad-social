import json
import os
import tempfile
import unittest
from pathlib import Path

from app import build_predictor
from src.infrastructure.logistic_no_show import LogisticNoShowPredictor
from src.infrastructure.rule_based_no_show import RuleBasedNoShowPredictor

ARTIFACT = Path(__file__).resolve().parents[1] / "ml" / "artifacts" / "no_show_logreg_v1.json"


def feats(**kw):
    base = {"lead_days": 5.0, "hour_local": 10, "prior_no_shows": 0,
            "prior_cancellations": 0, "reschedule_count": 0}
    base.update(kw)
    return base


class LogisticNoShowTest(unittest.TestCase):
    def setUp(self):
        self.model = LogisticNoShowPredictor(ARTIFACT)

    def test_flag_threshold_comes_from_the_artifact(self):
        self.assertEqual(self.model.FLAG_THRESHOLD, 0.3153)
        self.assertEqual(RuleBasedNoShowPredictor().FLAG_THRESHOLD, 0.30)

    def test_probability_in_range_and_named(self):
        r = self.model.predict(feats())
        self.assertTrue(0 < r["probability"] < 1)
        self.assertEqual(r["model"], "logreg-calibrated-v1")

    def test_more_prior_no_shows_raises_risk(self):
        p = [self.model.predict(feats(prior_no_shows=n))["probability"] for n in (0, 1, 2, 3)]
        self.assertEqual(p, sorted(p))
        self.assertLess(p[0], p[-1])
        self.assertIn("Inasistencias previas",
                      self.model.predict(feats(prior_no_shows=2))["factors"])

    def test_longer_lead_raises_risk(self):
        near = self.model.predict(feats(lead_days=2))["probability"]
        far = self.model.predict(feats(lead_days=30))["probability"]
        self.assertLess(near, far)

    def test_factors_only_name_what_is_true_of_the_appointment(self):
        # Una cita de un día de anticipación NO es «del mismo día»: no debe decirse que lo es.
        factors = self.model.predict(feats(lead_days=1))["factors"]
        self.assertNotIn("Cita agendada para el mismo día", factors)
        far = self.model.predict(feats(lead_days=30))["factors"]
        self.assertIn("Cita agendada con mucha anticipación", far)
        self.assertNotIn("Cita agendada para el mismo día", far)
        same_day = self.model.predict(feats(lead_days=0))["factors"]
        self.assertNotIn("Cita agendada para el mismo día", same_day)   # reduce el riesgo, no lo explica

    def test_extreme_inputs_are_capped(self):
        a = self.model.predict(feats(prior_no_shows=50, lead_days=500))
        b = self.model.predict(feats(prior_no_shows=3, lead_days=60))
        self.assertEqual(a["probability"], b["probability"])

    def test_ignores_other_signals(self):
        # Solo anticipación e inasistencias previas; cualquier otro dato se ignora.
        a = self.model.predict(feats(hour_local=7, prior_cancellations=4, reschedule_count=3))
        b = self.model.predict(feats())
        self.assertEqual(a["probability"], b["probability"])

    def test_invalid_artifact_is_rejected(self):
        art = json.loads(ARTIFACT.read_text(encoding="utf-8"))
        art["features"] = ["age", "lead_log", "same_day"]
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "m.json"
            path.write_text(json.dumps(art), encoding="utf-8")
            with self.assertRaises(ValueError):
                LogisticNoShowPredictor(path)

    def test_build_predictor_falls_back_to_rules(self):
        self.assertIsInstance(build_predictor(""), RuleBasedNoShowPredictor)
        self.assertIsInstance(build_predictor("no-existe.json"), RuleBasedNoShowPredictor)
        self.assertIsInstance(build_predictor(str(ARTIFACT)), LogisticNoShowPredictor)

    def test_relative_model_path_does_not_depend_on_working_directory(self):
        cwd = os.getcwd()
        with tempfile.TemporaryDirectory() as elsewhere:
            os.chdir(elsewhere)
            try:
                predictor = build_predictor("ml/artifacts/no_show_logreg_v1.json")
            finally:
                os.chdir(cwd)
        self.assertIsInstance(predictor, LogisticNoShowPredictor)


if __name__ == "__main__":
    unittest.main()

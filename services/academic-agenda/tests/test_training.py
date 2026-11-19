import json

import joblib

from ml.train import FEATURES, generate_calendars, train


def test_synthetic_training_is_reproducible_and_matches_contract(tmp_path):
    first_x, first_y = generate_calendars(n=60)
    second_x, second_y = generate_calendars(n=60)
    assert first_x.equals(second_x)
    assert first_y.tolist() == second_y.tolist()
    assert list(first_x.columns) == FEATURES

    model_path = tmp_path / "model.joblib"
    report_path = tmp_path / "evaluation.json"
    result = train(model_path, report_path)
    assert result == json.loads(report_path.read_text(encoding="utf-8"))
    assert result["source"] == "synthetic_calendars_only"
    assert 0 <= result["model_f1_macro"] <= 1
    assert 0 <= result["baseline_f1_macro"] <= 1
    model = joblib.load(model_path)
    assert list(model.feature_names_in_) == FEATURES

"""Entrena el clasificador de carga con calendarios sintéticos reproducibles.

Las etiquetas proceden de la regla de este generador, no de estudiantes reales.
"""
import argparse
import json
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import f1_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import make_pipeline
from sklearn.preprocessing import StandardScaler

ROOT = Path(__file__).resolve().parents[1]
CONTRACT = json.loads(
    (ROOT / "src/infrastructure/models/contrato_modelo_agenda.json").read_text(
        encoding="utf-8"
    )
)
FEATURES = CONTRACT["features"]
LEVELS = CONTRACT["target"]
SEED = 20261117


def generate_calendars(n: int = 1800, seed: int = SEED):
    rng = np.random.default_rng(seed)
    rows, labels = [], []
    for _ in range(n):
        count = int(min(rng.poisson(6), 24))
        hours_by_day = np.zeros(7)
        exams = deliveries = urgent = high = missing = 0
        active_days = set()
        for _ in range(count):
            day = int(rng.integers(0, 7))
            active_days.add(day)
            kind = int(rng.integers(0, 5))
            exams += kind == 0
            deliveries += kind in (1, 2)
            urgent += day < 2
            high += rng.random() < 0.25
            without_duration = rng.random() < 0.1
            missing += without_duration
            if not without_duration:
                hours_by_day[day] += float(rng.gamma(2.0, 1.2))
        hours = float(hours_by_day.sum())
        row = {
            "horas_totales": hours,
            "num_actividades": count,
            "num_examenes": exams,
            "num_entregas": deliveries,
            "num_urgentes_48h": urgent,
            "num_prioridad_alta": high,
            "dias_con_actividades": len(active_days),
            "max_horas_dia": float(hours_by_day.max()),
            "concentracion_3dias": float(np.sort(hours_by_day)[-3:].sum() / hours)
            if hours else 0.0,
            "num_sin_duracion": missing,
        }
        # Etiqueta sintética de referencia: horas y entregas próximas.
        score = hours + 1.5 * urgent + 0.7 * high
        level = "BAJA" if score < 10 else "MODERADA" if score < 20 else "ALTA"
        rows.append(row)
        labels.append(level)
    return pd.DataFrame(rows, columns=FEATURES), np.array(labels)


def count_baseline(frame):
    return np.where(
        frame["num_actividades"] < 5, "BAJA",
        np.where(frame["num_actividades"] < 10, "MODERADA", "ALTA"),
    )


def train(output: Path, report: Path):
    frame, labels = generate_calendars()
    train_x, test_x, train_y, test_y = train_test_split(
        frame, labels, test_size=0.25, random_state=SEED, stratify=labels,
    )
    model = make_pipeline(
        SimpleImputer(strategy="median"),
        StandardScaler(),
        LogisticRegression(max_iter=2000, random_state=SEED),
    )
    model.fit(train_x, train_y)
    predictions = model.predict(test_x)
    baseline = count_baseline(test_x)
    results = {
        "seed": SEED,
        "source": "synthetic_calendars_only",
        "sample_count": len(frame),
        "test_count": len(test_x),
        "label_rule": "BAJA if hours+1.5*urgent+0.7*high<10; MODERADA if <20; else ALTA",
        "baseline_rule": "BAJA if activity_count<5; MODERADA if <10; else ALTA",
        "levels": LEVELS,
        "model_f1_macro": float(f1_score(test_y, predictions, labels=LEVELS, average="macro")),
        "baseline_f1_macro": float(f1_score(test_y, baseline, labels=LEVELS, average="macro")),
        "model_f1_per_class": dict(zip(LEVELS, map(float, f1_score(
            test_y, predictions, labels=LEVELS, average=None,
        )))),
        "baseline_f1_per_class": dict(zip(LEVELS, map(float, f1_score(
            test_y, baseline, labels=LEVELS, average=None,
        )))),
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, output)
    report.write_text(json.dumps(results, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return results


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=ROOT / "src/infrastructure/models/modelo_carga_academica.joblib")
    parser.add_argument("--report", type=Path, default=ROOT / "ml/evaluation.json")
    args = parser.parse_args()
    print(json.dumps(train(args.output, args.report), ensure_ascii=False, indent=2))

"""Entrena y evalúa el modelo de inasistencia con el conjunto público
"Medical Appointment No Shows" (Vitória, Brasil, 2016).

Uso (desde services/citas, con el venv activo y ml/data/appointments.rda):
    python ml/train_no_show.py

Decisiones de diseño (ver Estado_del_Arte_Inasistencia_Citas.md):
- Solo se usan variables de COMPORTAMIENTO DE AGENDA que Citas también tiene:
  anticipación e inasistencias previas. Edad, sexo, barrio y beca NO entran al
  modelo (equidad, E1/E2); se usan únicamente para auditar errores por subgrupo.
- Validación TEMPORAL (entrenar con citas pasadas, probar con las siguientes).
- Las inasistencias previas solo cuentan citas cuyo resultado ya se conocía al
  momento de agendar (sin fuga de información).
- Calibración de Platt sobre un tramo de validación separado.
"""
import json
import math
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
import pyreadr
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (average_precision_score, brier_score_loss,
                             precision_score, recall_score, roc_auc_score)

ROOT = Path(__file__).resolve().parent
DATA = ROOT / "data" / "appointments.rda"
ARTIFACT = ROOT / "artifacts" / "no_show_logreg_v1.json"
REPORT = ROOT / "artifacts" / "metrics_v1.json"

FEATURES = ["lead_log", "same_day", "prior_no_shows"]
LABELS = {
    "lead_log": "Cita agendada con mucha anticipación",
    "same_day": "Cita agendada para el mismo día",
    "prior_no_shows": "Inasistencias previas",
}
CAP_PRIOR = 3          # tope de inasistencias previas (igual que el servicio)
CAP_LEAD = 60          # tope de días de anticipación
FLAG_RATE = 0.20       # se marca el 20 % de citas con mayor riesgo (umbral por tasa)


def cargar() -> pd.DataFrame:
    df = list(pyreadr.read_r(DATA).values())[0].copy()
    df["sched"] = pd.to_datetime(df["ScheduledDay"]).dt.normalize()
    df["appt"] = pd.to_datetime(df["AppointmentDay"]).dt.normalize()
    df["y"] = (df["No_show"].astype(str) == "Yes").astype(int)
    df["lead_days"] = (df["appt"] - df["sched"]).dt.days
    n0 = len(df)
    df = df[(df["lead_days"] >= 0) & (df["Age"] >= 0) & (df["Age"] <= 110)].copy()
    print(f"Filas: {n0} -> {len(df)} (se descartan fechas inconsistentes y edades inválidas)")
    return df


def historial(df: pd.DataFrame) -> pd.Series:
    """Inasistencias previas por cita, contando solo resultados ya conocidos
    al agendar (cita anterior con fecha < fecha en que se agenda la actual)."""
    prior = np.zeros(len(df), dtype=int)
    pos = {idx: i for i, idx in enumerate(df.index)}
    for _, g in df.groupby("PatientId"):
        if len(g) == 1:
            continue
        g_sorted = g.sort_values("appt")
        dias = g_sorted["appt"].values
        acum = np.concatenate([[0], np.cumsum(g_sorted["y"].values)])
        # nº de citas previas con fecha < sched de cada cita de g
        k = np.searchsorted(dias, g["sched"].values, side="left")
        for idx, kk in zip(g.index, k):
            prior[pos[idx]] = acum[kk]
    return pd.Series(prior, index=df.index)


def preparar(df: pd.DataFrame) -> pd.DataFrame:
    df["prior_no_shows"] = historial(df).clip(upper=CAP_PRIOR)
    df["lead_log"] = np.log1p(df["lead_days"].clip(upper=CAP_LEAD))
    df["same_day"] = (df["lead_days"] == 0).astype(int)
    return df


def ece(y, p, bins=10) -> float:
    edges = np.linspace(0, 1, bins + 1)
    idx = np.clip(np.digitize(p, edges) - 1, 0, bins - 1)
    total = 0.0
    for b in range(bins):
        m = idx == b
        if m.any():
            total += m.mean() * abs(y[m].mean() - p[m].mean())
    return float(total)


def sigmoid(z):
    return 1.0 / (1.0 + np.exp(-z))


def metricas(y, p, umbral) -> dict:
    flag = (p >= umbral).astype(int)
    return {
        "auc_roc": round(float(roc_auc_score(y, p)), 4),
        "auc_pr": round(float(average_precision_score(y, p)), 4),
        "brier": round(float(brier_score_loss(y, p)), 4),
        "ece": round(ece(y, p), 4),
        "umbral": round(float(umbral), 4),
        "recall": round(float(recall_score(y, flag, zero_division=0)), 4),
        "precision": round(float(precision_score(y, flag, zero_division=0)), 4),
        "tasa_marcadas": round(float(flag.mean()), 4),
    }


def regla_v0(d: pd.DataFrame) -> np.ndarray:
    """Línea base v0 aplicada a las mismas variables disponibles."""
    p = np.full(len(d), 0.10)
    lead = d["lead_days"].values
    p += np.where(lead > 7, np.minimum((lead - 7) * 0.02, 0.15), 0.0)
    p += 0.20 * np.minimum(d["prior_no_shows"].values, 3)
    return np.clip(p, 0.02, 0.85)


def por_subgrupo(test: pd.DataFrame, p: np.ndarray, umbral: float) -> dict:
    """Auditoría de equidad: variables que NO entran al modelo."""
    out = {}
    t = test.assign(p=p, flag=(p >= umbral).astype(int))
    grupos = {
        "sexo": t["Gender"].astype(str),
        "edad": pd.cut(t["Age"], [-1, 17, 29, 59, 200],
                       labels=["0-17", "18-29", "30-59", "60+"]).astype(str),
        "beca": t["Scholarship"].map({0.0: "sin_beca", 1.0: "con_beca"}),
    }
    for nombre, serie in grupos.items():
        filas = {}
        for g, sub in t.groupby(serie):
            if len(sub) < 200 or sub["y"].sum() < 20:
                continue
            filas[str(g)] = {
                "n": int(len(sub)),
                "tasa_real": round(float(sub["y"].mean()), 3),
                "prob_media": round(float(sub["p"].mean()), 3),
                "tasa_marcadas": round(float(sub["flag"].mean()), 3),
                "recall": round(float(recall_score(sub["y"], sub["flag"], zero_division=0)), 3),
                "precision": round(float(precision_score(sub["y"], sub["flag"], zero_division=0)), 3),
            }
        out[nombre] = filas
    return out


def main() -> None:
    df = preparar(cargar())
    df = df.sort_values(["appt", "sched"]).reset_index(drop=True)

    # Corte temporal por fecha de cita: 60 % entrena, 20 % calibra, 20 % prueba.
    fechas = df["appt"].drop_duplicates().sort_values().tolist()
    def corte(frac):  # fecha a partir de la cual cae el resto de filas
        objetivo = int(len(df) * frac)
        return df.iloc[objetivo]["appt"]
    c1, c2 = corte(0.60), corte(0.80)
    train = df[df["appt"] < c1]
    valid = df[(df["appt"] >= c1) & (df["appt"] < c2)]
    test = df[df["appt"] >= c2]
    print(f"train={len(train)} valid={len(valid)} test={len(test)} "
          f"(cortes {c1.date()} y {c2.date()})")
    print(f"tasa de inasistencia: train={train['y'].mean():.3f} "
          f"valid={valid['y'].mean():.3f} test={test['y'].mean():.3f}")

    # --- Regresión logística + calibración de Platt ---
    mu = train[FEATURES].mean().values
    sd = train[FEATURES].std(ddof=0).replace(0, 1).values
    z = lambda d: (d[FEATURES].values - mu) / sd
    lr = LogisticRegression(C=1.0, max_iter=1000).fit(z(train), train["y"])
    logit = lambda d: lr.decision_function(z(d))
    platt = LogisticRegression(C=1e6, max_iter=1000).fit(
        logit(valid).reshape(-1, 1), valid["y"])
    a, b = float(platt.coef_[0][0]), float(platt.intercept_[0])
    p_lr = lambda d: sigmoid(a * logit(d) + b)

    # --- Comparación: reglas v0, LR calibrada, gradient boosting ---
    gb = HistGradientBoostingClassifier(max_depth=3, learning_rate=0.05,
                                        max_iter=200, random_state=0)
    gb.fit(train[FEATURES].values, train["y"])
    p_gb = lambda d: gb.predict_proba(d[FEATURES].values)[:, 1]

    modelos = {"reglas_v0": regla_v0, "regresion_logistica_calibrada": p_lr,
               "gradient_boosting": p_gb}
    resultados = {}
    for nombre, fn in modelos.items():
        umbral = float(np.quantile(fn(valid), 1 - FLAG_RATE))
        resultados[nombre] = metricas(test["y"].values, fn(test), umbral)
    azar = float(test["y"].mean())
    resultados["referencia_azar"] = {"auc_pr": round(azar, 4), "auc_roc": 0.5,
                                     "recall": FLAG_RATE, "precision": round(azar, 4)}

    umbral_lr = float(np.quantile(p_lr(valid), 1 - FLAG_RATE))
    subgrupos = por_subgrupo(test, p_lr(test), umbral_lr)

    # --- Artefacto liviano: el servicio lo evalúa sin scikit-learn ---
    pesos = (lr.coef_[0] / sd).tolist()                       # sobre variables sin estandarizar
    sesgo = float(lr.intercept_[0] - np.sum(lr.coef_[0] * mu / sd))
    artefacto = {
        "name": "logreg-calibrated-v1",
        "type": "logistic_regression_platt",
        "features": FEATURES,
        "labels": LABELS,
        "weights": [round(w, 6) for w in pesos],
        "intercept": round(sesgo, 6),
        "platt": {"a": round(a, 6), "b": round(b, 6)},
        "feature_means": [round(float(m), 6) for m in train[FEATURES].mean().values],
        "caps": {"prior_no_shows": CAP_PRIOR, "lead_days": CAP_LEAD},
        "flag_threshold": round(umbral_lr, 4),
        "trained_on": {
            "dataset": "Medical Appointment No Shows (Joni Hoppen, Kaggle; copia vía qacData)",
            "rows_train": int(len(train)), "rows_valid": int(len(valid)),
            "rows_test": int(len(test)),
            "split": f"temporal: <{c1.date()} / <{c2.date()} / resto",
        },
        "limitations": [
            "Entrenado con atención médica general en Brasil (2016), no con estudiantes.",
            "Solo usa anticipación e inasistencias previas; sin historial el desempeño es bajo.",
            "Orientativo: solo para decidir recordatorios; nunca para negar o retrasar una cita.",
        ],
    }
    ARTIFACT.parent.mkdir(exist_ok=True)
    ARTIFACT.write_text(json.dumps(artefacto, ensure_ascii=False, indent=2), encoding="utf-8")
    REPORT.write_text(json.dumps({
        "metricas_test": resultados, "subgrupos_test_regresion_logistica": subgrupos,
        "cortes": [str(c1.date()), str(c2.date())],
        "cobertura_historial_test": round(float((test["prior_no_shows"] > 0).mean()), 4),
    }, ensure_ascii=False, indent=2), encoding="utf-8")

    print("\n=== Prueba (últimas fechas) ===")
    for k, v in resultados.items():
        print(f"{k:32s}", v)
    print("\nPesos (por unidad):", dict(zip(FEATURES, [round(w, 3) for w in pesos])),
          "sesgo", round(sesgo, 3), "platt", (round(a, 3), round(b, 3)))
    print("Citas de prueba con inasistencia previa:",
          f"{(test['prior_no_shows'] > 0).mean():.1%}")
    print("\nSubgrupos:", json.dumps(subgrupos, ensure_ascii=False, indent=1))
    print(f"\nGuardado: {ARTIFACT.relative_to(ROOT.parent)}, {REPORT.relative_to(ROOT.parent)}")


if __name__ == "__main__":
    main()

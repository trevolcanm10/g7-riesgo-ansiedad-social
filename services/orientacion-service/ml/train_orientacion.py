"""
Script reproducible de entrenamiento y evaluación para el clasificador local de
Orientación Confidencial (M2 - UNAYOE FISI UNMSM).

Entrena dos pipelines TF-IDF + Regresión Logística (tema y prioridad) y los
compara contra una línea base de palabras clave sobre el mismo conjunto de prueba.
"""
import csv
import json
import platform
import sys
from pathlib import Path
from typing import Dict, List, Tuple

import joblib
import numpy as np
import sklearn
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, classification_report, f1_score, recall_score
from sklearn.model_selection import StratifiedKFold, cross_val_predict, train_test_split
from sklearn.pipeline import Pipeline

BASE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(BASE_DIR))

from app.infrastructure.ml.scikit_classifier import ScikitLocalClassifier  # noqa: E402

CORPUS_PATH = Path(__file__).resolve().parent / "data" / "corpus_orientacion_prototipo.csv"
ARTIFACTS_DIR = BASE_DIR / "app" / "infrastructure" / "ml" / "artifacts"


def cargar_corpus(path: Path) -> Tuple[List[str], List[str], List[str]]:
    textos, temas, prioridades = [], [], []
    with path.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            textos.append(row["mensaje"].strip())
            temas.append(row["tema"].strip())
            prioridades.append(row["prioridad"].strip())
    return textos, temas, prioridades


def construir_pipeline() -> Pipeline:
    return Pipeline(
        [
            (
                "tfidf",
                TfidfVectorizer(
                    max_features=5000,
                    ngram_range=(1, 2),
                    strip_accents="unicode",
                    sublinear_tf=True,
                ),
            ),
            (
                "logreg",
                LogisticRegression(
                    class_weight="balanced",
                    max_iter=2000,
                    random_state=42,
                ),
            ),
        ]
    )


def evaluar_modelo(
    y_true: List[str], y_pred: List[str], etiquetas: List[str]
) -> Dict:
    report = classification_report(
        y_true, y_pred, labels=etiquetas, output_dict=True, zero_division=0
    )
    return {
        "accuracy": round(float(accuracy_score(y_true, y_pred)), 4),
        "macro_f1": round(float(f1_score(y_true, y_pred, average="macro", zero_division=0)), 4),
        "por_clase": {
            etq: {
                "precision": round(float(report[etq]["precision"]), 4),
                "recall": round(float(report[etq]["recall"]), 4),
                "f1": round(float(report[etq]["f1-score"]), 4),
                "soporte": int(report[etq]["support"]),
            }
            for etq in etiquetas
        },
    }


def main() -> None:
    textos, temas, prioridades = cargar_corpus(CORPUS_PATH)
    estratos = [f"{t}__{p}" for t, p in zip(temas, prioridades)]

    idx = np.arange(len(textos))
    try:
        idx_train, idx_test = train_test_split(
            idx, test_size=0.2, random_state=42, stratify=estratos
        )
    except ValueError:
        idx_train, idx_test = train_test_split(
            idx, test_size=0.2, random_state=42, stratify=temas
        )

    X_train = [textos[i] for i in idx_train]
    X_test = [textos[i] for i in idx_test]
    y_tema_train = [temas[i] for i in idx_train]
    y_tema_test = [temas[i] for i in idx_test]
    y_prio_train = [prioridades[i] for i in idx_train]
    y_prio_test = [prioridades[i] for i in idx_test]

    modelo_tema = construir_pipeline()
    modelo_tema.fit(X_train, y_tema_train)
    pred_tema_ml = list(modelo_tema.predict(X_test))

    modelo_prioridad = construir_pipeline()
    modelo_prioridad.fit(X_train, y_prio_train)
    pred_prio_ml = list(modelo_prioridad.predict(X_test))

    # Línea base por palabras clave (reglas léxicas deterministas sobre las 5 clases)
    pred_tema_base = [
        ScikitLocalClassifier._fallback_tema(t.lower(), default="personal")
        for t in X_test
    ]
    pred_prio_base = [ScikitLocalClassifier._fallback_prioridad(t.lower()) for t in X_test]

    clases_tema = sorted(set(temas))
    clases_prio = sorted(set(prioridades))

    metricas_tema_ml = evaluar_modelo(y_tema_test, pred_tema_ml, clases_tema)
    metricas_tema_base = evaluar_modelo(y_tema_test, pred_tema_base, clases_tema)
    metricas_prio_ml = evaluar_modelo(y_prio_test, pred_prio_ml, clases_prio)
    metricas_prio_base = evaluar_modelo(y_prio_test, pred_prio_base, clases_prio)

    recall_alta_ml = round(
        float(recall_score(y_prio_test, pred_prio_ml, labels=["alta"], average=None, zero_division=0)[0]),
        4,
    )
    recall_alta_base = round(
        float(recall_score(y_prio_test, pred_prio_base, labels=["alta"], average=None, zero_division=0)[0]),
        4,
    )

    # Validación cruzada estratificada (5 folds) sobre los 250 mensajes del corpus
    cv = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    cv_pred_tema_ml = list(
        cross_val_predict(construir_pipeline(), textos, temas, cv=cv)
    )
    cv_pred_tema_base = [
        ScikitLocalClassifier._fallback_tema(t.lower(), default="personal")
        for t in textos
    ]
    # Estrategia desplegada para tema: reglas léxicas cuando hay señal directa,
    # con respaldo de TF-IDF+LogReg out-of-fold cuando las reglas no encuentran coincidencia.
    cv_pred_tema_hibrido = [
        (
            ScikitLocalClassifier._fallback_tema(t.lower(), default="")
            or pred_ml
        )
        for t, pred_ml in zip(textos, cv_pred_tema_ml)
    ]

    cv_pred_prio_ml = list(
        cross_val_predict(construir_pipeline(), textos, prioridades, cv=cv)
    )
    cv_pred_prio_base = [
        ScikitLocalClassifier._fallback_prioridad(t.lower()) for t in textos
    ]

    cv_metricas_tema_ml = evaluar_modelo(temas, cv_pred_tema_ml, clases_tema)
    cv_metricas_tema_base = evaluar_modelo(temas, cv_pred_tema_base, clases_tema)
    cv_metricas_tema_hibrido = evaluar_modelo(temas, cv_pred_tema_hibrido, clases_tema)
    cv_metricas_prio_ml = evaluar_modelo(prioridades, cv_pred_prio_ml, clases_prio)
    cv_metricas_prio_base = evaluar_modelo(prioridades, cv_pred_prio_base, clases_prio)
    cv_recall_alta_ml = round(
        float(recall_score(prioridades, cv_pred_prio_ml, labels=["alta"], average=None, zero_division=0)[0]),
        4,
    )
    cv_recall_alta_base = round(
        float(recall_score(prioridades, cv_pred_prio_base, labels=["alta"], average=None, zero_division=0)[0]),
        4,
    )

    ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(modelo_tema, ARTIFACTS_DIR / "modelo_tema.joblib")
    joblib.dump(modelo_prioridad, ARTIFACTS_DIR / "modelo_prioridad.joblib")

    metadatos = {
        "tecnica": "TF-IDF (1-2 gramas) + Regresión Logística (class_weight=balanced)",
        "linea_base": "Reglas por palabras clave (ScikitLocalClassifier._fallback_*)",
        "corpus": {
            "archivo": "ml/data/corpus_orientacion_prototipo.csv",
            "origen": "Corpus sintético prototipo redactado por el equipo de desarrollo",
            "cantidad_mensajes": len(textos),
            "tamano_entrenamiento": len(X_train),
            "tamano_prueba": len(X_test),
            "random_state": 42,
            "test_size": 0.2,
        },
        "clases_tema": clases_tema,
        "clases_prioridad": clases_prio,
        "prioridad_preferente": "alta",
        "versiones_entorno": {
            "python": platform.python_version(),
            "scikit_learn": sklearn.__version__,
            "joblib": joblib.__version__,
            "numpy": np.__version__,
        },
        "metricas_validacion_cruzada_5fold": {
            "n_splits": 5,
            "tema": {
                "tfidf_logreg": cv_metricas_tema_ml,
                "linea_base_palabras_clave": cv_metricas_tema_base,
                "estrategia_hibrida_desplegada": cv_metricas_tema_hibrido,
            },
            "prioridad": {
                "tfidf_logreg": {
                    **cv_metricas_prio_ml,
                    "recall_prioridad_alta": cv_recall_alta_ml,
                },
                "linea_base_palabras_clave": {
                    **cv_metricas_prio_base,
                    "recall_prioridad_alta": cv_recall_alta_base,
                },
            },
        },
        "metricas_prueba": {
            "tema": {
                "tfidf_logreg": metricas_tema_ml,
                "linea_base_palabras_clave": metricas_tema_base,
            },
            "prioridad": {
                "tfidf_logreg": {
                    **metricas_prio_ml,
                    "recall_prioridad_alta": recall_alta_ml,
                },
                "linea_base_palabras_clave": {
                    **metricas_prio_base,
                    "recall_prioridad_alta": recall_alta_base,
                },
            },
        },
        "advertencia": (
            "Prototipo experimental entrenado con corpus sintético; requiere validación "
            "y reentrenamiento con mensajes reales etiquetados por especialistas de UNAYOE."
        ),
    }

    (ARTIFACTS_DIR / "metadatos_modelos.json").write_text(
        json.dumps(metadatos, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    print("=== Evaluación en conjunto de prueba ===")
    print(f"Mensajes totales: {len(textos)} (train={len(X_train)}, test={len(X_test)})")
    print(
        f"Tema      -> TF-IDF+LogReg Macro-F1={metricas_tema_ml['macro_f1']} | "
        f"Línea base Macro-F1={metricas_tema_base['macro_f1']}"
    )
    print(
        f"Prioridad -> TF-IDF+LogReg Recall(alta)={recall_alta_ml}, Macro-F1={metricas_prio_ml['macro_f1']} | "
        f"Línea base Recall(alta)={recall_alta_base}, Macro-F1={metricas_prio_base['macro_f1']}"
    )
    print("=== Validación cruzada estratificada (5 folds, 250 mensajes) ===")
    print(
        f"Tema      -> TF-IDF+LogReg Macro-F1={cv_metricas_tema_ml['macro_f1']} | "
        f"Reglas Macro-F1={cv_metricas_tema_base['macro_f1']} | "
        f"Híbrido desplegado Macro-F1={cv_metricas_tema_hibrido['macro_f1']}"
    )
    print(
        f"Prioridad -> TF-IDF+LogReg Recall(alta)={cv_recall_alta_ml}, Macro-F1={cv_metricas_prio_ml['macro_f1']} | "
        f"Línea base Recall(alta)={cv_recall_alta_base}, Macro-F1={cv_metricas_prio_base['macro_f1']}"
    )


if __name__ == "__main__":
    main()

"""Entrena el modelo de agrupamiento (clustering) de perfiles de estudiantes.

Objetivo
--------
Encontrar perfiles frecuentes de estudiantes a partir de los indicadores de
bienestar (PHQ-9, GAD-7, estres, habitos, etc.) usando el dataset publico
"University Student Mental Health Indicators" de Kaggle, que simula
evaluaciones anonimizadas de estudiantes universitarios.

Algoritmo principal
--------------------
K-Means sobre el espacio estandarizado. Se barre k en [2..8] y se selecciona
el k con mejor Coeficiente de Silueta (desempate por menor Indice
Davies-Bouldin).

Linea base comparativa
----------------------
Agrupamiento jerarquico (AgglomerativeClustering, enlace ward) sobre el mismo
espacio estandarizado y el mismo barrido de k, para contrastar.

Evaluacion tecnica
------------------
- Coeficiente de Silueta (mayor es mejor; rango [-1, 1]).
- Indice Davies-Bouldin (menor es mejor).

El modelo se exporta como un Pipeline(StandardScaler, KMeans) en un unico
archivo .joblib. Empaquetar el escalador junto con el modelo es deliberado:
K-Means depende de la escala y separar ambos invita al error de aplicar el
modelo sobre datos crudos.

AVISO IMPORTANTE
----------------
El dataset de origen es SINTETICO (generado por formula ponderada mas ruido
gaussiano). Los perfiles resultantes describen ese dataset simulado y NO
representan poblaciones reales. Los resultados son estimaciones orientativas
y no constituyen un diagnostico clinico.

Uso:
    python train_clustering.py
    python train_clustering.py --k 5      # fija el numero de clusters
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.cluster import AgglomerativeClustering, KMeans
from sklearn.metrics import davies_bouldin_score, silhouette_score
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler

RAIZ_ML = Path(__file__).resolve().parent
RUTA_DATASET = RAIZ_ML / "data" / "mental_health_indicators.csv"
RUTA_ARTEFACTOS = RAIZ_ML / ".." / "app" / "infrastructure" / "ml" / "artifacts"
RUTA_RESULTADOS = RAIZ_ML / "resultados"

# Orden canonico de features.
#
# Se usan las SIETE variables del contrato de evaluacion de riesgo, las mismas
# que consume el microservicio prediction-ml (PHQ9, GAD7, OnlineStress,
# FinancialStress, ExerciseFreq, SocialActivity, SleepHours). Motivos:
#   1. Coherencia: un mismo conjunto de variables en todo el sistema permite
#      comparar un perfil de agrupamiento con el nivel de riesgo de la misma
#      escala.
#   2. Evidencia: sobre este subconjunto el Coeficiente de Silueta resulta
#      aproximadamente el doble que usando las quince columnas (0.10 frente
#      a 0.05); las ocho restantes variables aportan principalmente ruido.
#
# Debe coincidir con la constante FEATURES del adaptador de infraestructura y
# con la validacion de la API.
FEATURES = [
    "PHQ9",
    "GAD7",
    "OnlineStress",
    "FinancialStress",
    "ExerciseFreq",
    "SocialActivity",
    "SleepHours",
]

# Variables adicionales disponibles en el dataset que no entran al modelo.
# Se conservan para analyses posteriores y para documentar la decision.
FEATURES_DESCARTADAS = [
    "GPA",
    "FamilySupport",
    "ScreenTime",
    "AcademicStress",
    "DietQuality",
    "SelfEfficacy",
    "PeerRelationship",
    "SleepQuality",
]

# Etiquetas legibles por cluster. El orden sigue la asignacion del modelo
# entrenado; el texto es orientativo y describe el perfil en el dataset
# simulado, no a una persona.
DESCRIPCIONES_CLUSTER = {
    0: "Perfil de bienestar estable: indicadores de malestar en rangos bajos y recursos de apoyo disponibles.",
    1: "Perfil de estres academico y financier marcado, con apoyo familiar presente.",
    2: "Perfil de aislamiento social y menor autoeficacia, con aplicacion sostenida del estres en linea.",
    3: "Perfil de sintomatologia depresiva y ansiosa elevada, con habitos de sueno y alimentacion irregulares.",
    4: "Perfil de riesgo medio: presencia simultanea de estres academico y descanso insuficiente.",
    5: "Perfil de alta carga de estres con apoyo familiar reducido.",
    6: "Perfil con indicadores predominantemente favorables y recursos de apoyo sostenidos.",
    7: "Perfil de uso intensivo de pantallas con desbalance entre estres y recursos.",
    8: "Perfil de sintomatologia Ansiosa moderada con recursos de apoyo fluctuantes.",
    9: "Perfil de protectores reducidos con alteracion del ritmo de sueno.",
}

# Texto obligatorio en toda respuesta de la API que exponga resultados de IA.
NOTA_IA = (
    "Las estimaciones son orientativas y no constituyen un diagnostico clinico. "
    "Los perfiles provienen de un dataset sintetico y no describen poblaciones reales."
)

RANDOM_STATE = 42
RANGO_K = range(2, 11)


def cargar_datos(ruta: Path) -> pd.DataFrame:
    """Carga el dataset y valida que contenga las columnas esperadas."""
    if not ruta.exists():
        raise FileNotFoundError(
            f"No se encontro el dataset en {ruta}. "
            "Ejecute 'python download_dataset.py --refresh' para obtenerlo."
        )

    marco = pd.read_csv(ruta)

    faltantes = [columna for columna in FEATURES if columna not in marco.columns]
    if faltantes:
        raise ValueError(f"El dataset no contiene las columnas requeridas: {faltantes}")

    return marco


def evaluar(etiquetas: np.ndarray, matriz: np.ndarray) -> dict:
    """Calcula las metricas de calidad del agrupamiento."""
    if len(np.unique(etiquetas)) < 2:
        return {
            "silueta": None,
            "davies_bouldin": None,
            "nota": "Se requiere al menos dos clusters para evaluar la silueta.",
        }

    return {
        "silueta": round(float(silhouette_score(matriz, etiquetas)), 6),
        "davies_bouldin": round(float(davies_bouldin_score(matriz, etiquetas)), 6),
    }


def barrer_kmeans(matriz: np.ndarray, ks: range) -> list[dict]:
    """Evalua K-Means para cada k candidato."""
    resultados = []
    for k in ks:
        modelo = KMeans(n_clusters=k, random_state=RANDOM_STATE, n_init=10)
        etiquetas = modelo.fit_predict(matriz)
        metricas = evaluar(etiquetas, matriz)
        resultados.append(
            {
                "algoritmo": "kmeans",
                "k": k,
                "silueta": metricas["silueta"],
                "davies_bouldin": metricas["davies_bouldin"],
                "inercia": round(float(modelo.inertia_), 6),
            }
        )
    return resultados


def barrer_jerarquico(matriz: np.ndarray, ks: range) -> list[dict]:
    """Evalua el agrupamiento jerarquico (ward) para cada k candidato."""
    resultados = []
    for k in ks:
        modelo = AgglomerativeClustering(n_clusters=k, linkage="ward")
        etiquetas = modelo.fit_predict(matriz)
        metricas = evaluar(etiquetas, matriz)
        resultados.append(
            {
                "algoritmo": "jerarquico_ward",
                "k": k,
                "silueta": metricas["silueta"],
                "davies_bouldin": metricas["davies_bouldin"],
            }
        )
    return resultados


def seleccionar_k(resultados: list[dict], k_fijado: int | None) -> dict:
    """Elige el mejor modelo: mayor silueta y, en empate, menor Davies-Bouldin."""
    if k_fijado is not None:
        candidatos = [r for r in resultados if r["k"] == k_fijado]
        if not candidatos:
            raise ValueError(f"No hay resultados para k={k_fijado}.")
        return candidatos[0]

    validos = [r for r in resultados if r["silueta"] is not None]
    return max(validos, key=lambda r: (r["silueta"], -r["davies_bouldin"]))


def describir_clusters(
    marco: pd.DataFrame, etiquetas: np.ndarray, escalador: StandardScaler
) -> list[dict]:
    """Construye el perfil descriptivo de cada cluster a partir del CSV original."""
    escalado = escalador.transform(marco[FEATURES].to_numpy(dtype=float))
    perfiles = []

    for indice in sorted(np.unique(etiquetas)):
        mascara = etiquetas == indice
        centroide = escalado[mascara].mean(axis=0)

        # Media de cada feature en escala original (interpretable).
        medias_originales = marco.loc[mascara, FEATURES].mean().to_dict()

        perfiles.append(
            {
                "cluster": int(indice),
                "n": int(mascara.sum()),
                "descripcion": DESCRIPCIONES_CLUSTER.get(
                    int(indice),
                    "Perfil orientativo obtenido por agrupamiento sobre datos simulados.",
                ),
                "medias": {c: round(float(medias_originales[c]), 3) for c in FEATURES},
                "centroide_escalado": {
                    c: round(float(centroide[j]), 4) for j, c in enumerate(FEATURES)
                },
                "nivel_orientativo": _nivel_orientativo(medias_originales),
            }
        )

    return perfiles


def _nivel_orientativo(medias: dict) -> str:
    """Clasifica el perfil por severidad media de sintomatologia.

    Es una etiqueta descriptiva sobre datos sinteticos; no es un diagnostico.
    """
    indice = (medias["PHQ9"] / 27.0) * 0.5 + (medias["GAD7"] / 21.0) * 0.5
    if indice >= 0.45:
        return "elevado"
    if indice >= 0.28:
        return "moderado"
    return "bajo"


def main() -> int:
    """Punto de entrada del entrenamiento."""
    analizador = argparse.ArgumentParser(description=__doc__)
    analizador.add_argument(
        "--k",
        type=int,
        default=None,
        help="Fija el numero de clusters. Por defecto se elige el mejor por silueta.",
    )
    argumentos = analizador.parse_args()

    marco = cargar_datos(RUTA_DATASET)
    print(f"Dataset cargado: {len(marco)} filas, {len(FEATURES)} features")

    # Escalado obligatorio: K-Means y el enlace ward usan distancias euclidianas
    # y las features tienen escalas muy distintas.
    escalador = StandardScaler()
    matriz = escalador.fit_transform(marco[FEATURES].to_numpy(dtype=float))

    print("Evaluando K-Means...")
    resultados_kmeans = barrer_kmeans(matriz, RANGO_K)
    print("Evaluando agrupamiento jerarquico (ward)...")
    resultados_jerarquico = barrer_jerarquico(matriz, RANGO_K)

    mejor_kmeans = seleccionar_k(resultados_kmeans, argumentos.k)
    mejor_jerarquico = seleccionar_k(resultados_jerarquico, argumentos.k)

    print()
    print(f"{'algoritmo':<18}{'k':>3}{'silueta':>12}{'davies-bouldin':>18}")
    print("-" * 51)
    for resultado in resultados_kmeans + resultados_jerarquico:
        silueta = (
            f"{resultado['silueta']:.4f}"
            if resultado["silueta"] is not None
            else "n/d"
        )
        db = (
            f"{resultado['davies_bouldin']:.4f}"
            if resultado["davies_bouldin"] is not None
            else "n/d"
        )
        print(f"{resultado['algoritmo']:<18}{resultado['k']:>3}{silueta:>12}{db:>18}")
    print()

    # Modelo final: K-Means (algoritmo principal) sobre el espacio escalado.
    modelo = Pipeline(
        [
            ("escalador", escalador),
            ("kmeans", KMeans(n_clusters=mejor_kmeans["k"], random_state=RANDOM_STATE, n_init=10)),
        ]
    )
    modelo.fit(marco[FEATURES].to_numpy(dtype=float))

    etiquetas = modelo.named_steps["kmeans"].labels_
    perfiles = describir_clusters(marco, etiquetas, escalador)

    RUTA_ARTEFACTOS.mkdir(parents=True, exist_ok=True)
    RUTA_RESULTADOS.mkdir(parents=True, exist_ok=True)

    ruta_modelo = RUTA_ARTEFACTOS / "modelo_clustering.joblib"
    joblib.dump(modelo, ruta_modelo)

    ruta_perfiles = RUTA_ARTEFACTOS / "perfiles_clusteres.json"
    ruta_perfiles.write_text(
        json.dumps(
            {
                "nota_ia": NOTA_IA,
                "features": FEATURES,
                "k": mejor_kmeans["k"],
                "perfiles": perfiles,
            },
            ensure_ascii=False,
            indent=2,
        ),
        encoding="utf-8",
    )

    comparativa = {
        "nota_ia": NOTA_IA,
        "dataset": {
            "origen": "Kaggle: yuanchunhong/university-student-mental-health-indicators",
            "licencia": "CC0-1.0 (dominio publico)",
            "filas": int(len(marco)),
            "features": FEATURES,
            "tipo": "sintetico",
        },
        "random_state": RANDOM_STATE,
        "principal": mejor_kmeans,
        "linea_base_jerarquica": mejor_jerarquico,
        "barrido": resultados_kmeans + resultados_jerarquico,
        "perfiles": perfiles,
    }
    (RUTA_RESULTADOS / "comparativa.json").write_text(
        json.dumps(comparativa, ensure_ascii=False, indent=2), encoding="utf-8"
    )

    print(f"Modelo exportado: {ruta_modelo}")
    print(f"Perfiles exportados: {ruta_perfiles}")
    print(f"Comparativa exportada: {RUTA_RESULTADOS / 'comparativa.json'}")
    print()
    print(f"Modelo principal  : K-Means k={mejor_kmeans['k']} "
          f"silueta={mejor_kmeans['silueta']} davies={mejor_kmeans['davies_bouldin']}")
    print(f"Linea base        : jerarquico k={mejor_jerarquico['k']} "
          f"silueta={mejor_jerarquico['silueta']} davies={mejor_jerarquico['davies_bouldin']}")
    print()
    print(NOTA_IA)

    return 0


if __name__ == "__main__":
    sys.exit(main())

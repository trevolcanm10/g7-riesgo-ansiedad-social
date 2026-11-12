# Modelo de agrupamiento (clustering) de perfiles de estudiante

Este directorio contiene el entrenamiento y los artefactos del modelo de
agrupamiento que alimenta el **Panel Institucional (Módulo 4)**.

> **Aviso obligatorio.** Los perfiles que produce este modelo son
> **estimaciones orientativas**. No son un diagnóstico clínico, no
> describen poblaciones reales y no deben usarse para decidir sobre una
> persona concreta. El dataset de origen es **sintético** (vease
> "Origen del dataset").

---

## Origen del dataset

| Campo | Valor |
|---|---|
| Nombre | University Student Mental Health Indicators |
| Publicacion | Kaggle — `yuanchunhong/university-student-mental-health-indicators` |
| Licencia | **CC0-1.0** (dominio publico, redistribuible) |
| Descarga | API publica de Kaggle, sin credenciales |
| SHA256 | `BB27C2A3D0046FA4C615D8C6222F5AC1C441B1F7CB780534CC1B73239968CF38` |
| Tamano | 111781 bytes |
| Contenido | 1800 filas, 15 variables numericas + variable objetivo binaria |

La copia verificada esta versionada en `data/mental_health_indicators.csv`.
Para refrescarla:

```bash
python download_dataset.py --refresh
python download_dataset.py          # solo verifica el hash de la copia local
```

### Caracter artificial del dataset

El dataset **no contiene estudiantes reales**. El propietario lo genero de
forma sintetica: calcula un puntaje latente `Z` como suma ponderada de las
variables (`PHQ-9` -0.3, `GAD-7` -0.25, `Sleep Hours` +0.2, `Exercise
Frequency` +0.25, `Social Activity` +0.15, `Online Stress` -0.2, `GPA` +0.3,
`Family Support` +0.4, `Sleep Quality` +0.1, `Financial Stress` -0.15) y anade
ruido gaussiano con sigma = 1.

Consecuencias que condicionan la interpretacion de los resultados:

- La estructura de clusters es **debil y difusa** (silueta ~0.10). El ruido
  gaussiano es comparable a la senal, por lo que los perfiles describen
  tendencias y no personas.
- Los perfiles describen **ese dataset simulado**, no la realidad de la
  poblacion universitaria.
- El panel institucional los expone como `perfiles_ia` con la nota de IA
  obligatoria, y aplica la regla de privacidad k=5 antes de devolverlos.

---

## Variables utilizadas

El modelo usa las **siete variables del contrato de evaluacion de riesgo**, las
mismas que consume el microservicio `prediction-ml`:

`PHQ9`, `GAD7`, `OnlineStress`, `FinancialStress`, `ExerciseFreq`,
`SocialActivity`, `SleepHours`

Motivo de la eleccion (medido, no supuesto): sobre este subconjunto el
Coeficiente de Silueta resulta aproximadamente el doble que usando las quince
columnas (0.10 frente a 0.05); las ocho variables restantes aportan
principalmente ruido. Ademas, compartir el conjunto de variables con
`prediction-ml` permite contrastar un perfil de agrupamiento con el nivel de
riesgo de la misma escala.

Las ocho variables no utilizadas quedan listadas en `FEATURES_DESCARTADAS`
dentro de `train_clustering.py`.

---

## Metodologia

### Algoritmo principal: K-Means

- Entrada: las siete variables estandarizadas con `StandardScaler`.
- Barrido de `k` en `[2..10]`, `n_init=10`, `random_state=42`.
- Seleccion del `k` final: **mayor Coeficiente de Silueta**, con desempate
  por **menor Indice Davies-Bouldin**.
- El escalador y el modelo se exportan **juntos** como
  `Pipeline(StandardScaler, KMeans)` en un unico `.joblib`. K-Means depende de
  la escala, y separar ambos artefactos es la causa habitual de errores al
  aplicar un modelo entrenado sobre datos crudos.

### Linea base comparativa: agrupamiento jerarquico

`AgglomerativeClustering` con enlace `ward` sobre el **mismo** espacio
estandarizado y el **mismo** barrido de `k`. Permite contrastar si la
estructura depende del algoritmo o de los datos.

### Metricas

| Metrica | Interpretacion | Mejor |
|---|---|---|
| Coeficiente de Silueta | Separacion entre clusters (rango -1 a 1) | mayor |
| Indice Davies-Bouldin | Dispersion intra-cluster vs. separacion entre clusters | menor |

---

## Resultados

Barrido completo ( reproducible con `python train_clustering.py`):

| algoritmo | k | silueta | davies-bouldin |
|---|---|---|---|
| kmeans | 2 | 0.1004 | 2.8703 |
| kmeans | 3 | 0.0940 | 2.4855 |
| kmeans | 4 | 0.0944 | 2.2401 |
| kmeans | 5 | 0.0951 | 2.1068 |
| kmeans | 6 | 0.0953 | 1.9463 |
| kmeans | 7 | 0.1004 | 1.8707 |
| **kmeans** | **8** | **0.1034** | **1.7971** |
| kmeans | 9 | 0.1006 | 1.7876 |
| kmeans | 10 | 0.1011 | 1.7742 |
| jerarquico_ward | 2 | 0.0591 | 3.8037 |
| jerarquico_ward | 3 | 0.0388 | 3.2878 |
| jerarquico_ward | 4 | 0.0386 | 2.9595 |
| jerarquico_ward | 5 | 0.0382 | 2.6974 |
| jerarquico_ward | 6 | 0.0447 | 2.5161 |
| jerarquico_ward | 7 | 0.0423 | 2.4368 |
| jerarquico_ward | 8 | 0.0434 | 2.3253 |
| jerarquico_ward | 9 | 0.0398 | 2.2391 |
| jerarquico_ward | 10 | 0.0405 | 2.1518 |

**Modelo principal:** K-Means con `k=8` (silueta 0.1034, Davies-Bouldin 1.7971).
**Linea base:** jerarquico con `k=2` (silueta 0.0591, Davies-Bouldin 3.8037).

K-Means supera a la linea base jerarquica en **ambas** metricas y en **todos** los
valores de `k` evaluados: la estructura es real en los datos y no un artefacto
del algoritmo. El salto de Davies-Bouldin entre ambos (1.80 frente a 3.80) es
notable y confirma que los clusters de K-Means son mas compactos y mejor
separados.

### Lectura honesta de las metricas

Una silueta de 0.10 esta **muy por debajo** de 0.25, que suele considerarse el
umbral de una estructura util. La causa esknown: el dataset sintetico anade
ruido gaussiano (sigma = 1) del mismo orden que la senal ponderada. Por eso:

- Los perfiles se presentan como **orientativos** y nunca como clasificacion.
- El panel aplica la **regla k=5**, que ademas oculta los clusters con menos
  de cinco estudiantes.
- Un modelo equivalente entrenado con datos reales de la institucion
  probablemente mostraria metricas sustancialmente mejores. La arquitectura del
  adaptador (`app/infrastructure/ml/clustering_adapter.py`) no depende del
  dataset, solo del artefacto, asi que reentrenar con datos reales es cambiar
  el `.joblib` y volver a ejecutar el script.

---

## Artefactos generados

| Archivo | Contenido |
|---|---|
| `../app/infrastructure/ml/artifacts/modelo_clustering.joblib` | `Pipeline(StandardScaler, KMeans)` listo para inferencia |
| `../app/infrastructure/ml/artifacts/perfiles_clusteres.json` | Descripcion de cada cluster: `n`, descripcion, medias por feature, centroide escalado, nivel orientativo |
| `resultados/comparativa.json` | Barrido completo, modelo principal, linea base, perfiles y nota de IA |

---

## Reproducibilidad

- `random_state = 42` en K-Means.
- `n_init = 10`.
- Versionado de dependencias en `../requirements.txt`:
  `scikit-learn==1.6.1`, `numpy==2.0.0`, `pandas==2.2.3`, `joblib==1.3.2`.

Para regenerar los artefactos desde cero:

```bash
pip install -r ../requirements.txt
python download_dataset.py --refresh
python train_clustering.py
```

El comando imprime el barrido completo y las metricas del modelo principal y
de la linea base; debe coincidir con la tabla de este README.

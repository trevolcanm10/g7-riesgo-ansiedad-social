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
  por **menor Indice Davies-Bouldin**, y solo entre los `k` que **no son
  claramente menos estables** que el `k` mas simple (vease la seccion
  "Estabilidad entre ejecuciones").
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
| ARI (Adjusted Rand Index) | Estabilidad: parecido entre dos particiones del mismo conjunto de datos | mas alto |

---

## Resultados

Barrido completo ( reproducible con `python train_clustering.py`):

| algoritmo | k | silueta | davies-bouldin |
|---|---|---|---|
| **kmeans** | **2** | **0.1004** | **2.8703** |
| kmeans | 3 | 0.0940 | 2.4855 |
| kmeans | 4 | 0.0944 | 2.2401 |
| kmeans | 5 | 0.0951 | 2.1068 |
| kmeans | 6 | 0.0953 | 1.9463 |
| kmeans | 7 | 0.1004 | 1.8707 |
| kmeans | 8 | 0.1034 | 1.7971 |
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

**Modelo principal:** K-Means con `k=2` (silueta 0.1004, Davies-Bouldin 2.8703).
**Linea base:** jerarquico con `k=2` (silueta 0.0591, Davies-Bouldin 3.8037).

K-Means supera a la linea base jerarquica en **ambas** metricas y en **todos** los
valores de `k` evaluados, pero esa diferencia **no demuestra que la estructura
sea real**: la silueta del `k=8` supera a la del `k=2` en apenas 0.003, una
diferencia dentro del ruido de la metrica, y la medicion de estabilidad muestra
que el `k=8` es claramente menos estable (vease la seccion siguiente). Por eso el
`k` definitivo es 2: la diferencia de silueta no compensa la perdida de
estabilidad y, ademas, dos perfiles son mucho mas interpretables para el
personal que ocho.

### Estabilidad entre ejecuciones

Una silueta alta no garantiza que el agrupamiento se repita: un `k` puede ser
un artefacto del azar de la inicializacion. Por eso se mide la estabilidad con
el **ARI** (*Adjusted Rand Index*), que compara dos particiones del mismo
conjunto de datos de forma invariante a las etiquetas:

- **Entre semillas:** se repite K-Means con cuatro semillas distintas y una
  sola inicializacion (`n_init=1`) y se promedian los seis pares de ARI.
- **Entre submuestras:** se ajusta sobre el 80 por ciento de los datos (cinco
  repeticiones) y se compara con el ajuste completo sobre todas las filas.

| k | ARI entre semillas | ARI entre submuestras | ARI promedio |
|---|---|---|---|
| **2** | **0.4780** | **0.6400** | **0.5590** |
| 3 | 0.2023 | 0.2824 | 0.2423 |
| 4 | 0.2109 | 0.2055 | 0.2082 |
| 5 | 0.2286 | 0.2468 | 0.2377 |
| 6 | 0.1911 | 0.2254 | 0.2082 |
| 7 | 0.2195 | 0.2221 | 0.2208 |
| 8 | 0.2600 | 0.3557 | 0.3078 |
| 9 | 0.3005 | 0.2994 | 0.3000 |
| 10 | 0.2800 | 0.2655 | 0.2727 |

Lectura: el `k=2` es con diferencia el mas estable (ARI promedio 0.56 frente a
0.31 del `k=8` y menos de 0.31 en el resto). El criterio reproducido en
`train_clustering.py` descarta un `k` cuando su ARI promedio es peor en mas de
0.05 que el del `k` mas simple; con los datos de este dataset solo el `k=2`
supera el corte, de modo que el modelo publicado es el de `k=2`.

Los resultados completos quedan en `resultados/comparativa.json`, en la clave
`estabilidad`.

### Lectura honesta de las metricas

Una silueta de 0.10 esta **muy por debajo** de 0.25, que suele considerarse el
umbral de una estructura util. La causa es conocida: el dataset sintetico anade
ruido gaussiano (sigma = 1) del mismo orden que la senal ponderada. Por eso:

- Los perfiles se presentan como **orientativos** y nunca como clasificacion.
- El `k` se eligio tambien por **estabilidad** entre ejecuciones, no solo
  por silueta: un agrupamiento que cambia entre ejecuciones no es
  interpretable.
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
| `resultados/comparativa.json` | Barrido completo, estabilidad (ARI), modelo principal, linea base, perfiles y nota de IA |

---

## Revision de los perfiles por el equipo institucional (UNAYOE)

**Estado: PENDIENTE.** La revision de los perfiles y de sus textos por
parte del equipo institucional de UNAYOE **no se ha realizado**. En
consecuencia, las descripciones de los perfiles (`DESCRIPCIONES_CLUSTER` en
`train_clustering.py`) son las que propone el codigo y **no han sido
validadas por el personal institucional**.

Cuando se realice, este apartado debe recoger:

- quien reviso los perfiles y con que fecha;
- que observaciones se hicieron sobre cada perfil;
- que ajustes se aplicaron a las descripciones y al modelo.

Mientras tanto, la advertencia del modelo sintetico que viaja en cada
respuesta de la API (`nota_ia`) es la unica garantia de uso responsable.

---

## Reproducibilidad

- `random_state = 42` en K-Means.
- `n_init = 10`.
- Semillas, proporcion de submuestra y repeticiones de la medicion de
  estabilidad: `SEMILLAS_ESTABILIDAD`, `PROPORCION_SUBSAMPLE` y
  `REPETICIONES_SUBSAMPLE` en `train_clustering.py`.
- Versionado de dependencias en `../requirements.txt` (`scikit-learn==1.6.1`,
  `numpy==2.0.0`, `joblib==1.3.2`) y `../requirements-dev.txt`
  (`pandas==2.2.3`, que solo hace falta para entrenar).

Para regenerar los artefactos desde cero:

```bash
pip install -r ../requirements-dev.txt
python download_dataset.py --refresh
python train_clustering.py
```

El comando imprime el barrido completo y las metricas del modelo principal y
de la linea base; debe coincidir con la tabla de este README.

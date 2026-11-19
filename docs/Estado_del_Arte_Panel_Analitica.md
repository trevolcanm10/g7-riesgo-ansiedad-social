# Estado del arte - Panel institucional y analitica (Módulo 4)

> Documento de referencia del módulo 4. Todas las referencias que aparecen aquí se
> han verificado **una a una** en Crossref (`https://api.crossref.org/works/<doi>`),
> comprobando autores, título, revista, año y DOI. No se cita ningún trabajo
> cuyos datos no se hayan contrastado.

El panel institucional resume la atención psicosocial que recibe el
estudiante y la cruza con perfiles de agrupamiento. Este documento encuadra las
decisiones técnicas del módulo: cómo se agrupan los estudiantes, con qué
métricas se evalúa el agrupamiento, cómo se comprueba que el resultado sea
estable y cómo se protege la privacidad de los estudiantes en un tablero
institucional.

---

## 1. Qué se busca en la literatura

| Necesidad del módulo | Área de la literatura | Sección |
|---|---|---|
| Agrupar estudiantes por indicadores de salud mental | Perfiles latentes y agrupamiento en salud mental | [2](#2-agrupamiento-de-estudiantes-en-salud-mental-universitaria) |
| Elegir entre K-Means y agrupamiento jerárquico | Comparación de algoritmos y métricas internas | [3](#3-k-means-frente-al-agrupamiento-jerarquico) |
| Medir si el agrupamiento es bueno | Silueta, Davies-Bouldin, índice Rand ajustado | [4](#4-metricas-de-validez-interna) |
| Comprobar que el resultado no depende del azar | Estabilidad entre ejecuciones | [5](#5-estabilidad-entre-ejecuciones) |
| No reidentificar a un estudiante en el tablero | k-anonimato y control de divulgación | [6](#6-k-anonimato-y-supresion-de-celdas-en-tableros-institucionales) |

---

## 2. Agrupamiento de estudiantes en salud mental universitaria

En salud mental universitaria, los perfiles no se construyen a partir de un
diagnóstico sino de **indicadores de autoinforme** (sintomatología, estrés,
sueño, conducta). El patrón metodológico más extendido es el de los **perfiles
latentes**: se agrupa a los estudiantes en grupos que comparten un conjunto de
características y se interpreta cada grupo como un perfil, nunca como una
categoría clínica.

- Kökçam, B., Arslan, C. y Traş, Z. (2022). *Do Psychological Resilience and
 Emotional Intelligence Vary Among Stress Profiles in University Students? A
 Latent Profile Analysis*. Frontiers in Psychology, 12, art. 788506.
 DOI: `10.3389/fpsyg.2021.788506`
- Liu, Y., Lu, L. y Yao, Y. (2026). *Associations of psychological capital
 latent profiles with depression and anxiety: A cross-sectional study in
 Chinese college students*. Public Health, 255, art. 106275.
 DOI: `10.1016/j.puhe.2026.106275`

**Qué toma este módulo de ahí:** los perfiles se presentan como *estimaciones
orientativas* construidas sobre indicadores agregados, nunca como una
clasificación clínica ni como una evaluación individual. El modelo se entrenó
con un **dataset sintético**, de modo que sus perfiles describen la estructura
del indicador, no a la población real de la institución.

---

## 3. K-Means frente al agrupamiento jerárquico

Los dos algoritmos que se comparan en este módulo son los dos extremos
habituales: K-Means (particiona minimizando la inercia dentro de cada grupo) y
el agglomerativo jerárquico (construye un árbol de grupos). La comparación
práctica de ambos, con sus criterios de elección, está en el texto de
referencia clásico del área:

- Kaufman, L. y Rousseeuw, P. J. (1990). *Finding Groups in Data: An
 Introduction to Cluster Analysis*. Wiley Series in Probability and Statistics.
 Wiley. DOI: `10.1002/9780470316801`

**Qué hace este módulo:** entrena K-Means como modelo principal y usa el
jerárquico agglomerativo con enlace *ward* como **línea base** de comparación.
Con los datos del módulo, K-Means domina en silueta y en Davies-Bouldin para
todos los valores de `k` evaluados, y además es el único de los dos que se
puede volver a entrenar y exportar de forma reproducible para el servicio. El
jerárquico se queda, en el mejor caso, en `k=2` con silueta 0.0591 frente a los
0.1004 de K-Means.

---

## 4. Métricas de validez interna

| Métrica | Qué mide | Referencia | Valor del modelo publicado |
|---|---|---|---|
| Silueta | Separación de cada elemento respecto a la silueta media del grupo más cercano | Rousseeuw (1987) | 0.1004 |
| Davies-Bouldin | Dispersión interna frente a la separación entre grupos | Davies y Bouldin (1979) | 2.8703 |
| Índice Rand ajustado (ARI) | Acuerdo entre dos particiones de los mismos datos | Hubert y Arabie (1985) | 0.5590 (promedio) |

- Rousseeuw, P. J. (1987). *Silhouettes: A graphical aid to the interpretation
 and validation of cluster analysis*. Journal of Computational and Applied
 Mathematics, 20, 53-65. DOI: `10.1016/0377-0427(87)90125-7`
- Davies, D. L. y Bouldin, D. W. (1979). *A Cluster Separation Measure*. IEEE
 Transactions on Pattern Analysis and Machine Intelligence, PAMI-1(2), 224-227.
 DOI: `10.1109/TPAMI.1979.4766909`
- Hubert, L. y Arabie, P. (1985). *Comparing partitions*. Journal of
 Classification, 2, 193-218. DOI: `10.1007/BF01908075`

**Lectura honesta:** una silueta de 0,10 está muy por debajo de 0,25, el valor
que suele considerarse útil para una estructura interpretable. La causa
conocida es el propio dataset sintético: el ruido gaussiano con el que se
generó es del mismo orden que la señal. Por eso la decisión de publicación no
se apoya solo en la silueta.

---

## 5. Estabilidad entre ejecuciones

Un agrupamiento puede tener métricas internarazonables y aun así cambiar por
completo al cambiar la semilla o al trabajar con una submuestra. La
estabilidad es, por tanto, un criterio de primera orden:

- von Luxburg, U. (2010). *Clustering Stability: An Overview*. Foundations and
 Trends in Machine Learning, 2, 235-274. DOI: `10.1561/2200000008`
- Tibshirani, R., Walther, G. y Hastie, T. (2001). *Estimating the Number of
 Clusters in a Data Set Via the Gap Statistic*. Journal of the Royal
 Statistical Society Series B, 63, 411-423. DOI: `10.1111/1467-9868.00293`

**Método aplicado en este módulo** (reproducible, en
`ml/train_clustering.py`):

1. **Entre semillas:** se entrena K-Means con cuatro semillas distintas
 (`42`, `7`, `123`, `2024`) y se calcula el ARI medio de los seis pares.
2. **Entre submuestras:** se ajusta el modelo sobre cinco submuestras
 independientes del 80 % de los datos y se compara cada ajuste con el
 agrupamiento completo mediante ARI.
3. **Regla de decisión:** se descarta todo `k` cuyo ARI promedio sea peor en
 más de 0,05 que el del `k` más simple; entre los que sobreviven, se elige el
 de mejor silueta y, en caso de empate, el de menor Davies-Bouldin.

| `k` | ARI entre semillas | ARI entre submuestras | ARI promedio |
|---|---|---|---|
| 2 | 0.4780 | 0.6400 | **0.5590** |
| 3 | 0.2023 | 0.2824 | 0.2423 |
| 4 | 0.2109 | 0.2055 | 0.2082 |
| 5 | 0.2286 | 0.2468 | 0.2377 |
| 6 | 0.1911 | 0.2254 | 0.2082 |
| 7 | 0.2195 | 0.2221 | 0.2208 |
| 8 | 0.2600 | 0.3557 | 0.3078 |
| 9 | 0.3005 | 0.2994 | 0.3000 |
| 10 | 0.2800 | 0.2655 | 0.2727 |

**Resultado:** la regla deja únicamente `k=2`. La ventaja en silueta del `k=8`
(0,1034 frente a 0,1004, una diferencia de 0,003) es ruido estadístico y no
compensa su inestabilidad (ARI promedio 0,31 frente a 0,56). El modelo
publicado usa por tanto **`k=2`**, lo que además lo hace interpretable para el
personal: dos perfiles en lugar de ocho.

---

## 6. k-anonimato y supresión de celdas en tableros institucionales

Un tablero institucional publica datos de una población pequeña. El riesgo
clásico es la reidentificación: si una fila o una celda corresponde a una
persona o a un grupo mínimo, esa fila la identifica aunque no lleve nombres.

- Sweeney, L. (2002). *k-anonymity: A Model for Protecting Privacy*.
 International Journal on Uncertainty, Fuzziness and Knowledge-Based Systems,
 10(5), 557-570. DOI: `10.1142/S0218488502001648`
- Willenborg, L. y de Waal, T. (2001). *Disclosure Risk for Tabular Data*. En
 *Statistical Confidentiality*, Lecture Notes in Statistics, 137-157. Springer.
 DOI: `10.1007/978-1-4613-0121-9_6`

**Qué aplica este módulo** (regla `k=5`, implementada en
`app/domain/services/privacidad_k5.py`):

| Medida | Comportamiento |
|---|---|
| Agrupación con menos de 5 estudiantes | No se publica en ninguna respuesta |
| Total de atenciones menor que 5 | Se publica como nulo (`null`), no como número |
| Total con grupos ocultos | Se redondea a la baja a múltiplo de 5 y se marca como estimado |
| Casos que requieren seguimiento | Se suprimen si son menos de 5 |
| Celdas de riesgo por perfil | Se ocultan si el grupo tiene menos de 5 estudiantes |
| Número de grupos ocultos | Se publica solo si se han ocultado (indicador booleano) |
| Atenciones sin estudiante resuelto | Se cuenta en agregado y se publica suprimido si son menos de 5 |

La supresión es **complementaria**: además de ocultar los grupos pequeños, se
evita que restando el total visible de lo publicado se pueda reconstruir el
tamaño de los grupos ocultos.

---

## 7. Lo que este módulo no afirma

- El modelo **no diagnostica** y sus perfiles no son categorías clínicas.
- El dataset de origen es **sintético**: los perfiles describen la estructura
 del indicador, no a la población real de la institución.
- Los resultados de correlación son **agregados por nivel de riesgo**; el
 servicio nunca recibe ni devuelve riesgo individual de un estudiante.
- La revisión cualitativa de los perfiles por el equipo institucional
 (UNAYOE) está **pendiente**; no se registra como hecho.

---

## 8. Referencias verificadas

| # | Referencia | DOI | Verificación |
|---|---|---|---|
| 1 | Rousseeuw, P. J. (1987). Silhouettes: A graphical aid to the interpretation and validation of cluster analysis. Journal of Computational and Applied Mathematics, 20, 53-65. | `10.1016/0377-0427(87)90125-7` | Crossref |
| 2 | Davies, D. L. y Bouldin, D. W. (1979). A Cluster Separation Measure. IEEE Transactions on Pattern Analysis and Machine Intelligence, PAMI-1(2), 224-227. | `10.1109/TPAMI.1979.4766909` | Crossref |
| 3 | Hubert, L. y Arabie, P. (1985). Comparing partitions. Journal of Classification, 2, 193-218. | `10.1007/BF01908075` | Crossref |
| 4 | Kaufman, L. y Rousseeuw, P. J. (1990). Finding Groups in Data: An Introduction to Cluster Analysis. Wiley. | `10.1002/9780470316801` | Crossref |
| 5 | Tibshirani, R., Walther, G. y Hastie, T. (2001). Estimating the Number of Clusters in a Data Set Via the Gap Statistic. Journal of the Royal Statistical Society Series B, 63, 411-423. | `10.1111/1467-9868.00293` | Crossref |
| 6 | von Luxburg, U. (2010). Clustering Stability: An Overview. Foundations and Trends in Machine Learning, 2, 235-274. | `10.1561/2200000008` | Crossref |
| 7 | Sweeney, L. (2002). k-anonymity: A Model for Protecting Privacy. International Journal on Uncertainty, Fuzziness and Knowledge-Based Systems, 10(5), 557-570. | `10.1142/S0218488502001648` | Crossref |
| 8 | Willenborg, L. y de Waal, T. (2001). Disclosure Risk for Tabular Data. Statistical Confidentiality. Lecture Notes in Statistics, 137-157. | `10.1007/978-1-4613-0121-9_6` | Crossref |
| 9 | Kökçam, B., Arslan, C. y Traş, Z. (2022). Do Psychological Resilience and Emotional Intelligence Vary Among Stress Profiles in University Students? A Latent Profile Analysis. Frontiers in Psychology, 12, art. 788506. | `10.3389/fpsyg.2021.788506` | Crossref |
| 10 | Liu, Y., Lu, L. y Yao, Y. (2026). Associations of psychological capital latent profiles with depression and anxiety: A cross-sectional study in Chinese college students. Public Health, 255, art. 106275. | `10.1016/j.puhe.2026.106275` | Crossref |

---

## 9. Cómo se reprodujo la verificación

```bash
# Consulta de un DOI (devuelve autores, titulo, revista, ano y volumen)
curl -H "User-Agent: g7-panel-estado-arte/1.0 (mailto:correo@ejemplo.org)" \
 "https://api.crossref.org/works/10.1007/bf01908075"
```

Los resultados de agrupamiento y de estabilidad que se citan en este documento
son los que produce el propio módulo:

```bash
cd services/panel-service
python ml/train_clustering.py
```

El detalle queda en [`ml/README.md`](../services/panel-service/ml/README.md) y
en `ml/resultados/comparativa.json`.

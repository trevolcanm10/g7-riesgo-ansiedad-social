# Estado del arte: evaluación de riesgo y agenda académica (M1)

Referencias y resúmenes contrastados en las páginas originales el 17-nov-2026. Esta revisión usa los resúmenes y, cuando está disponible, el texto abierto; no sustituye la validación del sistema con estudiantes de la institución.

## 1. Pregunta

¿Qué fundamento tienen los modelos de árboles explicados con SHAP, los instrumentos PHQ-9 y GAD-7 y una clasificación de carga semanal para apoyar la orientación estudiantil?

## 2. Fuentes verificadas

| Referencia | Evidencia consultada | Aplicación y límite |
|---|---|---|
| [Chen y Guestrin (2016), XGBoost](https://arxiv.org/abs/1603.02754) | Los autores describen un sistema escalable de *tree boosting*. | Sustenta la familia de modelos usada por `prediction-ml`; el artículo no valida este modelo ni esta población. |
| [Lundberg et al. (2020), explicaciones para árboles](https://www.nature.com/articles/s42256-019-0138-9) | Presentan explicaciones locales mediante TreeExplainer y su agregación para entender modelos. | Fundamenta los factores SHAP. Las contribuciones son del modelo, no causas clínicas ni porcentajes de riesgo. |
| [Kroenke, Spitzer y Williams (2001), PHQ-9](https://pubmed.ncbi.nlm.nih.gov/11556941/) | Estudian la validez del PHQ-9 como medida breve de gravedad de síntomas depresivos. | Justifica registrar el instrumento; una puntuación aislada no equivale a diagnóstico. |
| [Spitzer et al. (2006), GAD-7](https://pubmed.ncbi.nlm.nih.gov/16717171/) | Evalúan una medida breve de síntomas de ansiedad generalizada. | Justifica registrar el instrumento; su uso en este flujo no demuestra validez local. |
| [Adams y Blair (2019), gestión del tiempo en ingeniería](https://journals.sagepub.com/doi/10.1177/2158244018824506) | En su muestra, el control percibido del tiempo se correlacionó con el promedio académico. | Da contexto a los avisos de planificación. No establece umbrales de horas ni valida el clasificador de esta agenda. |

## 3. Brechas y decisiones del módulo

- No se ha validado el XGBoost de este repositorio con una cohorte local ni se dispone aquí del conjunto original para compararlo con los modelos anteriores. Las explicaciones SHAP describen su predicción, no una intervención ni un diagnóstico.
- El clasificador semanal se entrenó con calendarios **sintéticos** etiquetados por una regla del generador. Su evaluación reproducible está en `services/academic-agenda/ml/README.md`; esos resultados no prueban utilidad con estudiantes reales.
- El semáforo de 10/20 horas en Flutter es un respaldo cuando no está disponible el servicio, no un umbral respaldado por las fuentes anteriores. Los avisos preventivos se redactan como sugerencias de organización.
- Antes de afirmar efectividad o equidad en producción, se necesitarían datos propios, validación externa y una evaluación del uso real de los avisos.

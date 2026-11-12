# Evaluación offline del recomendador M5

## Propósito y protocolo

Se comparó el recomendador híbrido implementado con dos líneas base: popularidad global y contenido. La evaluación es reproducible y utiliza únicamente datos sintéticos; no mide el comportamiento ni el rendimiento académico de estudiantes reales.

El generador, con semilla `20261112`, crea 90 perfiles sintéticos distribuidos en tres temas, un catálogo de 30 actividades y 360 interacciones de entrenamiento. Para cada perfil se separa una actividad relevante como dato de prueba. Las actividades ya vistas durante el entrenamiento se retiran de los candidatos antes de calcular el top 5.

- **Precision@5:** aciertos divididos entre los 5 espacios recomendados por usuario.
- **Hit rate@5:** proporción de usuarios cuyo top 5 contiene su actividad de prueba.
- **Cobertura:** proporción del catálogo que aparece al menos una vez en los top 5.

## Resultados sintéticos

| Método | Precision@5 | Hit rate@5 | Cobertura |
|---|---:|---:|---:|
| Popularidad | 0.0267 | 0.1333 | 0.2667 |
| Basado en contenido | 0.1711 | 0.8556 | 0.9000 |
| Híbrido | 0.1644 | 0.8222 | 1.0000 |

En este escenario artificial, el híbrido mejora respecto a popularidad y muestra todo el catálogo a través de los distintos perfiles. El contenido supera al híbrido en las métricas de acierto porque el conjunto fue construido con intereses y cursos que coinciden directamente con la actividad reservada. Esto no demuestra que el híbrido sea mejor en uso real ni permite inferir resultados para estudiantes.

Los pesos vigentes son una línea base y no se ajustaron para favorecer este conjunto. Para una evaluación institucional se necesitan interacciones reales obtenidas con consentimiento, una separación temporal de entrenamiento y prueba, y validación con usuarios; este informe no usa datos personales, de riesgo ni de salud.

## Reproducir

Desde la raíz del repositorio, con Python 3.12:

    python services/academic-support/ml/evaluate_recommender.py

El comando imprime las métricas y actualiza `evaluation_results.json`. El generador y el cálculo de métricas están en `evaluate_recommender.py`.

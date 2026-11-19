# Clasificador semanal de carga académica

El modelo se entrena **solo con calendarios sintéticos** generados por
`train.py`. No contiene datos de estudiantes ni ha sido validado con ellos;
su nivel BAJA/MODERADA/ALTA es una ayuda para organizar tareas, no un
diagnóstico. Las etiquetas salen de la regla del propio generador:
`horas_totales + 1.5*num_urgentes_48h + 0.7*num_prioridad_alta`, con cortes
en 10 y 20. Por eso, una F1 alta mide qué tan bien aprende esa regla
sintética, no la utilidad clínica o académica real.

El generador usa `numpy.random.default_rng(20261117)`, crea 1800 calendarios
de hasta 24 actividades distribuidas entre siete días, duraciones gamma,
tipos, prioridades y un 10 % aproximado de actividades sin duración. Divide
75 % para entrenamiento y 25 % para prueba, con partición estratificada y
semilla fija. El modelo es `SimpleImputer` + `StandardScaler` +
`LogisticRegression`; la comparación fija usa solo el número de actividades
(BAJA <5, MODERADA <10, ALTA ≥10).

Con Python 3.12 y las versiones de `requirements.txt` (scikit-learn 1.8.0,
NumPy 2.0.0, pandas 3.0.1, joblib 1.5.3), ejecutar:

```bash
cd services/academic-agenda
python ml/train.py
python -m pytest tests -q
```

La ejecución genera `src/infrastructure/models/modelo_carga_academica.joblib`
y `ml/evaluation.json`. En la ejecución registrada, F1 macro fue **0.974834**
para el clasificador y **0.607524** para la regla de conteo; F1 por clase y
reglas exactas están en `evaluation.json`. Estos números son exclusivamente
del conjunto sintético de prueba. El semáforo local de Flutter usa 10/20 horas
solo como respaldo cuando no responde el clasificador remoto; sus cortes son
reglas de interfaz y no proceden de datos reales.

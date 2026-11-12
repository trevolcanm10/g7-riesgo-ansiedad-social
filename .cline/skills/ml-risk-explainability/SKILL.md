---
name: ml-risk-explainability
description: >
  Revisar el predictor de riesgo de ansiedad existente (CatBoost, KNN,
  LightGBM, RandomForest, XGBoost) y preparar la capa de explicabilidad
  SHAP sin tocar el ensamble ni las métricas.
  ACTIVAR: al leer/entender/generar métricas de predict_risk.py,
  ensemble_predictor.py, domain/risk.py o tests/test_prediction.py.
  NO ACTIVAR: al tocar código frontend, openapi, base de datos o la agenda
  académica; nunca cargar datasets ni modelos binarios.

# ml-risk-explainability

## Objetivo
Añadir explicabilidad SHAP al predictor de riesgo de ansiedad sin modificar
la arquitectura de ensamble.

## Flujo
1. Inspeccionar `services/prediction-ml/src/infrastructure/ensemble_predictor.py`
   para identificar `FEATURES` y `INDICATORS`.
2. Añadir `explain_risk(indicators)` que:
   - usa `shap.TreeExplainer` sobre cada modelo del ensamble (o sobre el
     mismo pipeline si se cambia el agrupador);
   - suma los valores SHAP por features;
   - devuelve un objeto con `top_factors: [{feature, impact, direction}]` y
     `mean_abs_shap`;
   - conserva la lógica de `predict_probability` sin alterarla.
3. Validar que el denominador de SHAP no sea cero; si `features` es
   `[None]`, lanzar `PredictionError("No se pueden calcular SHAP")`;
   no crear archivos auxiliares ni dependencias nuevas.
4. Emitir tres factores influyentes por `top_factors` cant (0.0–1.0);

## Restricciones
- Solo lectura de `ensemble_predictor.py` y `domain/risk.py`. No modificar
  `ensemble_predictor.py` salvo añadir un método nuevo.
- No cargar datasets, `.pkl` ni logs.
- No tocar la semántica de `categorize_risk` en `domain/risk.py`.
- No usar `shap` si no está declarado en `pyproject.toml` o
  `requirements.txt` del servicio.

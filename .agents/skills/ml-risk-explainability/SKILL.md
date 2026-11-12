---
name: ml-risk-explainability
description: Revisar el predictor de riesgo de ansiedad existente (CatBoost, KNN, LightGBM, RandomForest, XGBoost) y añadir explicabilidad SHAP sin modificar el ensamble. ACTIVAR: al leer/entender métricas de predict_risk.py, ensemble_predictor.py, domain/risk.py o tests/test_prediction.py. NO ACTIVAR: al tocar frontend, openapi, base de datos o agenda académica.
---

# ml-risk-explainability

## Objetivo
Añadir explicabilidad SHAP al predictor de riesgo de ansiedad. Conservar
completamente el ensamble de cinco modelos. Solo lectura de archivos existentes.

## Flujo
1. Inspeccionar `services/prediction-ml/src/infrastructure/ensemble_predictor.py`
   para extraer `FEATURES` e `INDICATORS`.
2. Añadir `explain_risk(indicators)` que:
   - usa `shap.TreeExplainer` sobre cada modelo del ensamble;
   - suma los valores SHAP por feature;
   - devuelve `top_factors: [{feature, impact, direction}]` y `mean_abs_shap`;
   - no altera `predict_probability`.
3. Validar denominador SHAP distinto de cero; si `features` es `[None]`,
   lanzar `PredictionError("No se pueden calcular SHAP")`.
4. Emitir tres factores influyentes (0.0–1.0) por `top_factors`.

## Restricciones
- No modificar `ensemble_predictor.py`, `domain/risk.py` salvo nuevo método.
- No cargar datasets, `.pkl`, logs ni entrenar modelos.
- No usar `shap` si no está en `pyproject.toml`/`requirements.txt`.
- No tocar la semántica de `categorize_risk`.
- Sin cambios en `openapi`, `frontend` ni `users`.

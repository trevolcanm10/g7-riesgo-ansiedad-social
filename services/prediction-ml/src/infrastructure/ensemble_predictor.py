# Eliminado: código obsoleto del ensamble de 5 modelos (soft voting).
# El servicio utiliza exclusivamente XGBoost con SHAP
# (src/infrastructure/xgboost_predictor.py), instanciado en app.py.
# Los artefactos anteriores pueden permanecer en models/, pero
# ensemble_predictor.py no se importa ni participa en la inferencia.

# Eliminado: código obsoleto del ensamble de 5 modelos (soft voting).
# El servicio utiliza exclusivamente XGBoost con SHAP
# (src/infrastructure/xgboost_predictor.py), instanciado en app.py.
# El artefacto catboost_weighted_model.pkl no existe en models/ y
# ensemble_predictor.py no es importado por app.py ni por ningún test.

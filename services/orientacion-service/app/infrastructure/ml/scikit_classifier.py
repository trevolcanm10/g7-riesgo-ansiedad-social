import joblib
import os
from typing import Tuple
from app.application.interfaces.ml_classifier_port import IMLClassifier

class ScikitLocalClassifier(IMLClassifier):
    def __init__(self):
        self.modelo_tema = None
        self.modelo_prioridad = None
        self._load_models()

    def _load_models(self):
        try:
            base_dir = os.path.dirname(__file__)
            tema_path = os.path.join(base_dir, 'artifacts', 'modelo_tema.joblib')
            prioridad_path = os.path.join(base_dir, 'artifacts', 'modelo_prioridad.joblib')

            if os.path.exists(tema_path) and os.path.exists(prioridad_path):
                self.modelo_tema = joblib.load(tema_path)
                self.modelo_prioridad = joblib.load(prioridad_path)
            else:
                print("Advertencia: No se encontraron los modelos .joblib, usando fallback")
        except Exception as e:
            print(f"Error cargando modelos de machine learning: {e}")

    def predict(self, text: str) -> Tuple[str, str]:
        tema = "personal"
        prioridad = "media"

        if self.modelo_tema:
            try:
                tema = self.modelo_tema.predict([text])[0]
            except Exception as e:
                print(f"Error prediccion tema: {e}")

        if self.modelo_prioridad:
            try:
                prioridad = self.modelo_prioridad.predict([text])[0]
            except Exception as e:
                print(f"Error prediccion prioridad: {e}")

        if not self.modelo_tema:
            texto_l = text.lower()
            if "curso" in texto_l or "nota" in texto_l: tema = "academico"
            elif "dinero" in texto_l or "pagar" in texto_l: tema = "economico"
            elif "ansiedad" in texto_l or "estrés" in texto_l: tema = "ansiedad_estres"
            elif "familia" in texto_l: tema = "familiar"

            if "urgente" in texto_l or "ayuda" in texto_l: prioridad = "alta"

        return tema, prioridad

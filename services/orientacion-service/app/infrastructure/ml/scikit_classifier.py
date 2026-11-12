import logging
import os
from typing import Tuple

import joblib

from app.application.interfaces.ml_classifier_port import IMLClassifier
from app.domain.entities.solicitud import PRIORIDADES_VALIDAS, TEMAS_VALIDOS

logger = logging.getLogger(__name__)


class ScikitLocalClassifier(IMLClassifier):
    def __init__(self, artifacts_dir: str | None = None):
        self.modelo_tema = None
        self.modelo_prioridad = None
        self._artifacts_dir = artifacts_dir or os.path.join(
            os.path.dirname(__file__), "artifacts"
        )
        self._load_models()

    @property
    def model_status(self) -> str:
        if self.modelo_tema is not None and self.modelo_prioridad is not None:
            return "trained-tfidf-logreg"
        return "keyword-fallback"

    def _load_models(self) -> None:
        tema_path = os.path.join(self._artifacts_dir, "modelo_tema.joblib")
        prioridad_path = os.path.join(self._artifacts_dir, "modelo_prioridad.joblib")

        if not (os.path.exists(tema_path) and os.path.exists(prioridad_path)):
            logger.warning(
                "No se encontraron los artefactos .joblib en %s; se usará el respaldo por palabras clave",
                self._artifacts_dir,
            )
            return

        try:
            self.modelo_tema = joblib.load(tema_path)
            self.modelo_prioridad = joblib.load(prioridad_path)
            logger.info("Modelos locales TF-IDF + Regresión Logística cargados correctamente")
        except Exception:
            logger.exception("Error cargando modelos de machine learning; se usará el respaldo")
            self.modelo_tema = None
            self.modelo_prioridad = None

    @staticmethod
    def _normalizar(texto: str) -> str:
        import unicodedata

        sin_tildes = "".join(
            ch
            for ch in unicodedata.normalize("NFKD", texto.lower())
            if not unicodedata.combining(ch)
        )
        return sin_tildes

    @classmethod
    def _fallback_tema(cls, texto_l: str) -> str:
        norm = cls._normalizar(texto_l)
        reglas = (
            ("economico", ("dinero", "pagar", "pago", "matricula", "pension", "beca", "economico", "economica", "trabajo", "deuda")),
            ("ansiedad_estres", ("ansiedad", "estres", "panico", "angustia", "nervios", "insomnio", "ataque")),
            ("familiar", ("familia", "padres", "mama", "papa", "casa", "hermano", "hermana", "hogar")),
            ("academico", ("curso", "nota", "examen", "parcial", "ciclo", "profesor", "tesis", "repitencia", "creditos")),
        )
        mejor_tema = "personal"
        mejor_puntaje = 0
        for tema, palabras in reglas:
            puntaje = sum(1 for p in palabras if p in norm)
            if puntaje > mejor_puntaje:
                mejor_puntaje = puntaje
                mejor_tema = tema
        return mejor_tema

    @classmethod
    def _fallback_prioridad(cls, texto_l: str) -> str:
        norm = cls._normalizar(texto_l)
        if any(p in norm for p in ("urgente", "crisis", "desesperado", "desesperada", "no puedo", "colapso")):
            return "alta"
        if any(p in norm for p in ("consulta", "duda", "informacion", "horarios")):
            return "baja"
        return "media"

    def predict(self, text: str) -> Tuple[str, str]:
        texto_l = text.lower()
        tema = self._fallback_tema(texto_l)
        prioridad = self._fallback_prioridad(texto_l)

        if self.modelo_tema is not None:
            try:
                pred_tema = str(self.modelo_tema.predict([text])[0])
                if pred_tema in TEMAS_VALIDOS:
                    tema = pred_tema
            except Exception:
                logger.exception("Error en inferencia local de tema; usando respaldo")

        if self.modelo_prioridad is not None:
            try:
                pred_prio = str(self.modelo_prioridad.predict([text])[0])
                if pred_prio in PRIORIDADES_VALIDAS:
                    prioridad = pred_prio
            except Exception:
                logger.exception("Error en inferencia local de prioridad; usando respaldo")

        return tema, prioridad

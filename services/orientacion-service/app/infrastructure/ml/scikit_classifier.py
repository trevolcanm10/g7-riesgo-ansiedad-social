import logging
import os
import re
from typing import Optional, Tuple

import joblib

from app.application.interfaces.ml_classifier_port import IMLClassifier
from app.domain.entities.solicitud import (
    PRIORIDADES_VALIDAS,
    TEMAS_SUGERIDOS,
    TEMAS_VALIDOS,
)

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

    _GREETINGS_ONLY = frozenset(
        {
            "hola",
            "holi",
            "buenas",
            "buenos dias",
            "buenas tardes",
            "buenas noches",
            "saludos",
            "hi",
            "hello",
            "hey",
            "ok",
            "gracias",
            "test",
            "prueba",
        }
    )

    _REGLAS_TEMA: Tuple[Tuple[str, Tuple[str, ...]], ...] = (
        (
            "economico",
            (
                "dinero",
                "pagar",
                "pago",
                "pagos",
                "matricula",
                "pension",
                "pensiones",
                "beca",
                "becas",
                "economico",
                "economica",
                "economicos",
                "trabajo",
                "deuda",
                "deudas",
                "alquiler",
                "prestamo",
                "pasajes",
                "ingresos",
                "finanzas",
            ),
        ),
        (
            "ansiedad_estres",
            (
                "ansiedad",
                "ansioso",
                "ansiosa",
                "estres",
                "estresado",
                "estresada",
                "panico",
                "angustia",
                "angustiado",
                "angustiada",
                "nervios",
                "nervioso",
                "nerviosa",
                "insomnio",
                "ataque",
                "ataques",
                "abrumado",
                "abrumada",
                "palpitaciones",
                "colapso",
                "agotado",
                "agotada",
            ),
        ),
        (
            "familiar",
            (
                "familia",
                "familiar",
                "familiares",
                "padres",
                "mama",
                "papa",
                "madre",
                "padre",
                "casa",
                "hermano",
                "hermana",
                "hogar",
                "divorcio",
                "discusion",
                "discusiones",
                "violencia",
            ),
        ),
        (
            "academico",
            (
                "curso",
                "cursos",
                "nota",
                "notas",
                "examen",
                "examenes",
                "parcial",
                "parciales",
                "final",
                "finales",
                "ciclo",
                "semestre",
                "profesor",
                "profesora",
                "docente",
                "tesis",
                "repitencia",
                "creditos",
                "calculo",
                "algoritmos",
                "laboratorio",
                "promedio",
                "fechas",
                "horarios",
            ),
        ),
        (
            "personal",
            (
                "soledad",
                "solo",
                "sola",
                "triste",
                "tristeza",
                "deprimido",
                "deprimida",
                "motivacion",
                "desmotivado",
                "desmotivada",
                "pareja",
                "relacion",
                "relaciones",
                "autoestima",
                "amigos",
                "amistad",
                "duelo",
                "aislamiento",
                "inseguro",
                "insegura",
                "vacio",
            ),
        ),
    )

    @staticmethod
    def _tokenizar(texto_norm: str) -> Tuple[str, ...]:
        return tuple(re.findall(r"[a-z0-9_]+", texto_norm))

    @classmethod
    def _fallback_tema(cls, texto_l: str, default: str = "sin_clasificar") -> str:
        norm = cls._normalizar(texto_l)
        tokens = set(cls._tokenizar(norm))
        if not tokens:
            return default

        mejor_tema = default
        mejor_puntaje = 0
        for tema, palabras in cls._REGLAS_TEMA:
            puntaje = sum(1 for p in palabras if p in tokens)
            if puntaje > mejor_puntaje:
                mejor_puntaje = puntaje
                mejor_tema = tema
        return mejor_tema

    @classmethod
    def _fallback_prioridad(cls, texto_l: str) -> str:
        norm = cls._normalizar(texto_l)
        if any(
            p in norm
            for p in (
                "urgente",
                "crisis",
                "desesperado",
                "desesperada",
                "no puedo",
                "no aguanto",
                "no soporto",
                "colapso",
            )
        ):
            return "alta"
        if any(p in norm for p in ("consulta", "duda", "informacion", "horarios")):
            return "baja"
        return "media"

    @staticmethod
    def _tfidf_nnz(pipeline, text: str) -> Optional[int]:
        try:
            named_steps = getattr(pipeline, "named_steps", None)
            if named_steps and "tfidf" in named_steps:
                return int(named_steps["tfidf"].transform([text]).nnz)
        except Exception:
            return None
        return None

    def _is_low_signal(self, text: str, tema_reglas: Optional[str]) -> bool:
        norm = self._normalizar(text)
        limpio = re.sub(r"[^\w\s]", "", norm).strip()
        if not limpio or limpio in self._GREETINGS_ONLY:
            return True
        if tema_reglas is not None:
            return False
        tokens = self._tokenizar(norm)
        return len(tokens) < 3

    def predict(self, text: str) -> Tuple[str, str]:
        texto_l = text.lower()
        tema_reglas: Optional[str] = self._fallback_tema(texto_l, default="") or None
        prioridad_reglas = self._fallback_prioridad(texto_l)

        # Mensajes vacíos de señal (saludos cortos, ruido tipo "asdfgh") no deben
        # recibir sesgo de intercepto del modelo lineal ni categoría arbitraria.
        if self._is_low_signal(text, tema_reglas):
            if self.modelo_tema is not None:
                nnz = self._tfidf_nnz(self.modelo_tema, text)
                if nnz is None or nnz < 2:
                    return "sin_clasificar", "baja"
            else:
                return "sin_clasificar", "baja"

        # Decisión validada por CV 5-fold (N6): las reglas léxicas superan a
        # TF-IDF+LogReg en tema en el corpus actual; ML actúa como respaldo si
        # no hubo coincidencia léxica pero sí suficiente vocabulario y confianza.
        if tema_reglas in TEMAS_VALIDOS:
            tema = tema_reglas
        else:
            tema = "sin_clasificar"
            if self.modelo_tema is not None:
                try:
                    nnz_tema = self._tfidf_nnz(self.modelo_tema, text)
                    if nnz_tema is None or nnz_tema >= 2:
                        if hasattr(self.modelo_tema, "predict_proba"):
                            probs = self.modelo_tema.predict_proba([text])[0]
                            clases = self.modelo_tema.classes_
                            idx_max = int(max(range(len(probs)), key=lambda i: probs[i]))
                            pred_tema = str(clases[idx_max])
                            if probs[idx_max] >= 0.40 and pred_tema in TEMAS_VALIDOS:
                                tema = pred_tema
                        else:
                            pred_tema = str(self.modelo_tema.predict([text])[0])
                            if pred_tema in TEMAS_VALIDOS:
                                tema = pred_tema
                except Exception:
                    logger.exception("Error en inferencia local de tema; usando respaldo")

        if tema == "sin_clasificar":
            return "sin_clasificar", "baja"

        prioridad = prioridad_reglas
        if self.modelo_prioridad is not None:
            try:
                nnz_prio = self._tfidf_nnz(self.modelo_prioridad, text)
                if nnz_prio is not None and nnz_prio == 0:
                    prioridad = "baja" if prioridad_reglas != "alta" else "alta"
                else:
                    pred_prio = str(self.modelo_prioridad.predict([text])[0])
                    if pred_prio in PRIORIDADES_VALIDAS:
                        # No degradar una señal léxica explícita de prioridad alta
                        prioridad = "alta" if prioridad_reglas == "alta" else pred_prio
            except Exception:
                logger.exception("Error en inferencia local de prioridad; usando respaldo")

        if tema not in TEMAS_SUGERIDOS:
            tema = "sin_clasificar"
        return tema, prioridad

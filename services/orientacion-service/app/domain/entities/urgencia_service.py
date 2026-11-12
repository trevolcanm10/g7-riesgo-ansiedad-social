import re
import unicodedata
from typing import Iterable, List, Optional, Tuple
from .solicitud import UrgenciaAnalisis

# Líneas oficiales verificadas en Perú (Minsa, SAMU, PNP).
# El contacto institucional de UNAYOE se inyecta por configuración (ORIENTACION_HELP_LINES)
# cuando la unidad provea el canal oficial, sin inventar números en el código.
DEFAULT_HELP_LINES: Tuple[str, ...] = (
    "Línea 113 MINSA (Opción 5 - Salud Mental): Orientación psicológica gratuita las 24 horas",
    "SAMU: 106 (Emergencias médicas prehospitalarias)",
    "Policía Nacional del Perú (PNP): 105 (Emergencias y auxilio inmediato)",
)


def _normalizar_texto(texto: str) -> str:
    sin_tildes = "".join(
        ch
        for ch in unicodedata.normalize("NFKD", texto.lower())
        if not unicodedata.combining(ch)
    )
    limpio = re.sub(r"[^\w\s]", " ", sin_tildes)
    return re.sub(r"\s+", " ", limpio).strip()


class UrgenciaDomainService:
    """
    Detector heurístico de crisis e ideación de riesgo vital.

    Limitación documentada: es una heurística de priorización sensible (no un
    diagnóstico clínico) y opera de forma independiente al clasificador ML.
    Toda solicitud es revisada por personal capacitado de UNAYOE.
    """

    # Patrones compilados sobre texto normalizado (sin tildes ni puntuación).
    CRITICAL_PATTERNS: Tuple[Tuple[str, re.Pattern[str]], ...] = (
        ("ideacion_suicida", re.compile(r"\bsuicid\w*\b")),
        ("quiero_morir", re.compile(r"\b(quiero|quisiera|deseo|ganas de)\s+morir\w*\b")),
        ("no_quiero_vivir", re.compile(r"\b(ya\s+)?no\s+quiero\s+(seguir\s+)?vivi(r|endo)\b")),
        ("quitarse_la_vida", re.compile(r"\b(quitarme|quitarse|acabar con|terminar con)\s+la\s+vida\b|\b(acabar|terminar)\s+con\s+mi\s+vida\b")),
        ("mejor_muerto", re.compile(r"\b(estaria|estar|seria)\s+mejor\s+muert[oa]\b|\bojala\s+(estuviera|amaneciera)\s+muert[oa]\b")),
        ("autolesion", re.compile(r"\bautolesion\w*\b|\b(hacer|hacerme|hacerse|hago)\s+dano\b|\blastimar\w*\b|\bherir(me|se)?\b|\bcortar(me|se)(\s+las\s+venas)?\b")),
        ("no_aguanto_mas", re.compile(r"\bno\s+(aguanto|puedo|soporto)\s+mas\b")),
        ("no_me_siento_seguro", re.compile(r"\bno\s+me\s+siento\s+segur[oa]\b|\bno\s+tengo\s+(un\s+)?lugar\s+segur[oa]\b")),
        ("seguridad_en_riesgo", re.compile(r"\bmi\s+seguridad\s+esta\s+en\s+riesgo\b|\btemo\s+por\s+mi\s+seguridad\b|\bestoy\s+en\s+peligro\b")),
        ("atencion_inmediata", re.compile(r"\bnecesito\s+(ayuda\s+(ahora|urgente|inmediata)|atencion\s+inmediata)\b|\bsituacion\s+critica\b")),
    )

    HELP_LINES: List[str] = list(DEFAULT_HELP_LINES)

    @classmethod
    def detectar(
        cls, texto: str, help_lines: Optional[Iterable[str]] = None
    ) -> UrgenciaAnalisis:
        texto_norm = _normalizar_texto(texto)
        coincidencias: List[str] = []
        for etiqueta, patron in cls.CRITICAL_PATTERNS:
            match = patron.search(texto_norm)
            if match:
                coincidencias.append(f"{etiqueta}: {match.group(0)}")

        es_urgente = len(coincidencias) > 0
        lineas = list(help_lines) if help_lines is not None else list(cls.HELP_LINES)
        lineas_limpias = [l.strip() for l in lineas if l and l.strip()]

        return UrgenciaAnalisis(
            es_urgente=es_urgente,
            coincidencias=coincidencias,
            lineas_ayuda=lineas_limpias if es_urgente else [],
        )

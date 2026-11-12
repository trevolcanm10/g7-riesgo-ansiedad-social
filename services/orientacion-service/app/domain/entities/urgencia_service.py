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
        ("quiero_morir", re.compile(r"\b(quiero|quisiera|deseo|ganas de|ojala)\s+morir\w*\b")),
        (
            "no_quiero_vivir",
            re.compile(
                r"\b(ya\s+)?no\s+quiero\s+(seguir\s+)?vivi(r|endo)\b"
                r"|\bpreferiria\s+no\s+(vivir|existir)\b"
            ),
        ),
        (
            "no_despertar",
            re.compile(
                r"\bojala\s+(?:ya\s+)?no\s+desp(?:ertar\w*|ierte)\b"
                r"|\bno\s+quiero\s+(?:volver\s+a\s+)?despertar\b"
                r"|\b(?:quisiera|ojala)\s+dormir\s+y\s+no\s+despertar\b"
            ),
        ),
        (
            "quitarse_la_vida",
            re.compile(
                r"\b(quitarme|quitarse|acabar con|terminar con)\s+(la\s+vida|todo)\b"
                r"|\b(acabar|terminar)\s+con\s+mi\s+vida\b"
            ),
        ),
        (
            "mejor_muerto",
            re.compile(
                r"\b(estaria|estar|seria)\s+mejor\s+muert[oa]\b"
                r"|\bojala\s+(estuviera|amaneciera)\s+muert[oa]\b"
                r"|\b(todos|todo|la gente|mi familia)\s+(estaria|estarian|seria)\s+mejor\s+sin\s+mi\b"
                r"|\bmejor\s+sin\s+mi\b"
            ),
        ),
        (
            "sin_sentido_vital",
            re.compile(
                r"\bno\s+(?:le\s+)?encuentro\s+sentido\s+a\s+(?:seguir(?:\s+viviendo)?|vivir|la\s+vida)\b"
                r"|\b(?:la\s+vida|seguir\s+viviendo)\s+(?:ya\s+)?no\s+tiene\s+sentido\b"
                r"|\bnada\s+tiene\s+sentido\b"
            ),
        ),
        (
            "desaparecer",
            re.compile(
                r"\b(quiero|quisiera|deseo|necesito|ojala\s+pudiera)\s+desaparecer\b"
            ),
        ),
        (
            "autolesion",
            re.compile(
                r"\bautolesion\w*\b"
                r"|\b(hacer|hacerme|hacerse|hago)\s+dano\b"
                r"|\bme\s+(hago|hice)\s+dano\b"
                r"|\blastimar(me|se)?\b|\bme\s+(lastimo|lastime)\b"
                r"|\bherir(me|se)?\b|\bme\s+hiero\b"
                r"|\bcortar(me|se)(\s+las\s+venas)?\b"
                r"|\bme\s+(corto|corte|cortaba|cortaria)(?!\s+(?:el\s+(?:pelo|cabello)|una|el\s+internet|el\s+agua|la\s+luz))\b"
            ),
        ),
        ("no_aguanto_mas", re.compile(r"\bno\s+(aguanto|puedo|soporto)\s+mas\b")),
        ("no_me_siento_seguro", re.compile(r"\bno\s+me\s+siento\s+segur[oa]\b|\bno\s+tengo\s+(un\s+)?lugar\s+segur[oa]\b")),
        ("seguridad_en_riesgo", re.compile(r"\bmi\s+seguridad\s+esta\s+en\s+riesgo\b|\btemo\s+por\s+mi\s+seguridad\b|\bestoy\s+en\s+peligro\b")),
        ("atencion_inmediata", re.compile(r"\bnecesito\s+(ayuda\s+(ahora|urgente|inmediata)|atencion\s+inmediata)\b|\bsituacion\s+critica\b")),
    )

    # Contextos no vitales (académicos/cotidianos) donde "no aguanto más X" indica
    # sobrecarga elevada sin constituir alerta de riesgo suicida.
    NON_VITAL_FRUSTRATION_PATTERN: re.Pattern[str] = re.compile(
        r"\bno\s+(?:aguanto|puedo|soporto)\s+mas(?:\s+con)?\s+"
        r"(?:(?:el|la|los|las|este|esta|estos|estas|ese|esa|tanto|tanta)\s+)*"
        r"(?:curso|cursos|materia|materias|examen|examenes|parcial|parciales|final|finales|"
        r"ciclo|semestre|profesor\w*|profe|docente\w*|horario|horarios|tarea|tareas|"
        r"practica|practicas|laboratorio|calculo|fisica|algebra|programacion|"
        r"trafico|calor|frio|ruido|bulla)\b"
    )

    HELP_LINES: List[str] = list(DEFAULT_HELP_LINES)

    @classmethod
    def detectar(
        cls, texto: str, help_lines: Optional[Iterable[str]] = None
    ) -> UrgenciaAnalisis:
        texto_norm = _normalizar_texto(texto)
        coincidencias: List[str] = []
        eleva_prioridad = False

        for etiqueta, patron in cls.CRITICAL_PATTERNS:
            match = patron.search(texto_norm)
            if not match:
                continue
            if (
                etiqueta == "no_aguanto_mas"
                and cls.NON_VITAL_FRUSTRATION_PATTERN.search(texto_norm)
            ):
                eleva_prioridad = True
                continue
            coincidencias.append(f"{etiqueta}: {match.group(0)}")

        es_urgente = len(coincidencias) > 0
        eleva_prioridad = es_urgente or eleva_prioridad
        lineas = list(help_lines) if help_lines is not None else list(cls.HELP_LINES)
        lineas_limpias = [l.strip() for l in lineas if l and l.strip()]

        return UrgenciaAnalisis(
            es_urgente=es_urgente,
            coincidencias=coincidencias,
            lineas_ayuda=lineas_limpias if es_urgente else [],
            eleva_prioridad=eleva_prioridad,
        )

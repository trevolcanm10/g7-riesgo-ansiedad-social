"""Reporting contract, independent of Flask and Gemini."""
from abc import ABC, abstractmethod
from typing import Mapping

TEXT_FIELDS = ('resumen', 'prioridad_intervencion', 'mensaje_motivacional')
LIST_LIMITS = {'fortalezas': 5, 'factores_preocupantes': 5,
               'recomendaciones': 5, 'plan_7_dias': 7,
               'temas_videos': 3, 'temas_lectura': 3}
REPORT_SCHEMA = {
    'type': 'object',
    'properties': {
        **{key: {'type': 'string'} for key in TEXT_FIELDS},
        **{key: {'type': 'array', 'items': {'type': 'string'}, 'maxItems': limit}
           for key, limit in LIST_LIMITS.items()},
    },
    'required': list(TEXT_FIELDS) + list(LIST_LIMITS),
    'additionalProperties': False,
}


def validate_report(report) -> dict:
    if not isinstance(report, dict) or set(report) != set(REPORT_SCHEMA['required']):
        raise ValueError('Invalid report fields')
    for key in TEXT_FIELDS:
        if not isinstance(report[key], str) or not report[key].strip():
            raise ValueError('Invalid report text')
    for key, limit in LIST_LIMITS.items():
        items = report[key]
        if (not isinstance(items, list) or len(items) > limit
                or any(not isinstance(item, str) or not item.strip() for item in items)):
            raise ValueError('Invalid report list')
    return {key: list(value) if isinstance(value, list) else value
            for key, value in report.items()}


class ReportGenerator(ABC):
    @abstractmethod
    def generate(self, indicators: Mapping[str, float], probability: float,
                 risk_level: str) -> dict:
        """Generate guidance without modifying the supplied ML result."""


# Explanation texts recovered from the original ResultadoML model.
EXPLANATIONS = {
    'BAJO': 'Tus indicadores muestran un equilibrio saludable. Continúa manteniendo estas rutinas.',
    'MEDIO': 'Se detectan ciertos niveles de alerta. Revisa tus horas de sueño y pausas activas.',
    'ALTO': 'Alta predisposición a ansiedad. Busca orientación en el departamento de bienestar estudiantil.',
}

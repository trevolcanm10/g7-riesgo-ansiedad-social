"""Optional modern Gemini adapter. No calls or clients at import time."""
import copy
import json
import os
import time

from src.domain.report import ReportGenerator, REPORT_SCHEMA, validate_report
from src.infrastructure.fallback_report_generator import FallbackReportGenerator


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON field')
        result[key] = value
    return result


# Gemini's generateContent validates response_schema against OpenAPI 3.0 and
# rejects additionalProperties, so that key is stripped for the wire only.
# deepcopy keeps nested structures independent from REPORT_SCHEMA, which
# remains the strict contract enforced by validate_report.
GEMINI_SCHEMA = copy.deepcopy(REPORT_SCHEMA)
GEMINI_SCHEMA.pop('additionalProperties', None)


def build_prompt(indicators, probability, risk_level):
    # Adapted from the original gemini_service.py; inputs contain no user identity.
    return f"""Eres un especialista en bienestar emocional universitario.
Analiza la siguiente evaluación para ofrecer orientación, no diagnóstico clínico.
Nivel de riesgo calculado por ML: {risk_level}
Probabilidad calculada por ML: {round(probability * 100, 2)}%
Variables: {json.dumps(dict(indicators), ensure_ascii=False)}
Genera únicamente JSON válido con esta estructura:
{json.dumps(REPORT_SCHEMA, ensure_ascii=False)}
Máximo 5 fortalezas, 5 factores_preocupantes y 5 recomendaciones.
Máximo 7 acciones para plan_7_dias, 3 temas_videos y 3 temas_lectura.
No recalcules el riesgo ni la probabilidad. No atribuyas causalidad al modelo.
No inventes circunstancias personales ni factores de apoyo no respaldados.
Aclara en resumen que es orientación generada por Gemini, no diagnóstico.
Responde SOLO JSON, sin markdown ni texto antes o después.
"""


class GeminiReportGenerator(ReportGenerator):
    def __init__(self, *, api_key=None, model=None, client_factory=None,
                 sleep=time.sleep):
        self._api_key = api_key if api_key is not None else os.getenv('GEMINI_API_KEY', '')
        self._model = model if model is not None else os.getenv('GEMINI_MODEL', '')
        self._factory = client_factory or self._create_client
        self._sleep = sleep
        self._fallback = FallbackReportGenerator()

    @staticmethod
    def _create_client(api_key):
        from google import genai
        from google.genai import types
        # Milliseconds; disable SDK retries so our two-attempt policy is authoritative.
        return genai.Client(api_key=api_key, http_options=types.HttpOptions(
            timeout=15000, retry_options=types.HttpRetryOptions(attempts=1)))

    def generate(self, indicators, probability, risk_level):
        if not self._api_key.strip() or not self._model.strip():
            return self._fallback.generate(indicators, probability, risk_level)
        client = None
        try:
            client = self._factory(self._api_key)
            for attempt in range(2):
                try:
                    response = client.models.generate_content(
                        model=self._model,
                        contents=build_prompt(indicators, probability, risk_level),
                        config={'response_mime_type': 'application/json',
                                'response_schema': GEMINI_SCHEMA,
                                'temperature': 0.2, 'max_output_tokens': 2048},
                    )
                    report = validate_report(json.loads(response.text, object_pairs_hook=_unique_object))
                    report['resumen'] += ' Orientación generada por Gemini; no constituye un diagnóstico clínico.'
                    return report
                except Exception as exc:
                    # Never log exception text, prompts, keys or generated content.
                    timeout = isinstance(exc, TimeoutError)
                    try:
                        import httpx
                        timeout = timeout or isinstance(exc, httpx.TimeoutException)
                    except ImportError:
                        pass
                    transient = timeout or getattr(exc, 'code', None) in (408, 429, 500, 502, 503, 504)
                    if not transient or attempt == 1:
                        break
                    self._sleep(0.25)
        except Exception:
            pass  # Missing SDK/configuration also uses a complete, safe fallback.
        finally:
            if client is not None:
                try:
                    client.close()
                except Exception:
                    pass
        return self._fallback.generate(indicators, probability, risk_level)

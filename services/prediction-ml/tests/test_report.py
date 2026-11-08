import copy
import json
import unittest
from types import SimpleNamespace
from unittest.mock import Mock, patch

from src.domain.report import REPORT_SCHEMA, validate_report, EXPLANATIONS
from src.infrastructure.fallback_report_generator import FallbackReportGenerator
from src.infrastructure.gemini_report_generator import (
    GeminiReportGenerator, build_prompt, GEMINI_SCHEMA)
from src.application.predict_risk import PredictRiskUseCase
from src.presentation.http import create_http_app
from test_prediction import PAYLOAD, FakePredictor


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.report = FallbackReportGenerator().generate(PAYLOAD, .42, 'MEDIO')

    def adapter(self, values):
        client = Mock()
        client.models.generate_content.side_effect = values
        return GeminiReportGenerator(api_key='dummy', model='mock-model',
            client_factory=lambda key: client, sleep=lambda seconds: None), client

    def test_contract_and_regression(self):
        for probability, level in [(0, 'BAJO'), (.35, 'MEDIO'), (.70, 'MEDIO'), (1, 'ALTO')]:
            predictor = FakePredictor(probability)
            generator = GeminiReportGenerator(api_key='', model='')
            client = create_http_app(PredictRiskUseCase(predictor, generator), 5).test_client()
            response = client.post('/predict', json=PAYLOAD)
            self.assertEqual(response.status_code, 200)
            self.assertEqual(set(response.json), {'probabilidad_ansiedad', 'nivel_riesgo', 'explicacion', 'reporte_ia'})
            self.assertEqual(response.json['probabilidad_ansiedad'], probability)
            self.assertEqual(response.json['nivel_riesgo'], level)
            self.assertIn(EXPLANATIONS[level], response.json['explicacion'])
            self.assertEqual(predictor.calls, 1)
            validate_report(response.json['reporte_ia'])

    def test_missing_configuration_never_constructs_client(self):
        for key, model in [('', 'model'), ('dummy', '')]:
            factory = Mock()
            adapter = GeminiReportGenerator(api_key=key, model=model, client_factory=factory)
            result = adapter.generate(PAYLOAD, .42, 'MEDIO')
            self.assertEqual(result, self.report)
            self.assertIn('determinista', result['resumen'])
            factory.assert_not_called()

    def test_success_and_prompt(self):
        generated = {**self.report, 'resumen': 'Orientación generada por Gemini; no es diagnóstico.'}
        adapter, client = self.adapter([SimpleNamespace(text=json.dumps(generated))])
        actual = adapter.generate(PAYLOAD, .42, 'MEDIO')
        self.assertTrue(actual['resumen'].startswith(generated['resumen']))
        self.assertIn('no constituye un diagnóstico', actual['resumen'])
        self.assertEqual({k: v for k, v in actual.items() if k != 'resumen'},
                         {k: v for k, v in generated.items() if k != 'resumen'})
        call = client.models.generate_content.call_args.kwargs
        self.assertEqual(call['model'], 'mock-model')
        self.assertIn('MEDIO', call['contents'])
        self.assertIn('42.0%', call['contents'])
        self.assertIn('No recalcules', call['contents'])
        client.close.assert_called_once()

    def test_strict_types_missing_extra_and_list_limits(self):
        invalid = [None, [], {**self.report, 'extra': 'x'}]
        for key, value in self.report.items():
            invalid.append({k: v for k, v in self.report.items() if k != key})
            invalid.append({**self.report, key: 1})
            if isinstance(value, list):
                invalid.extend([{**self.report, key: [1]}, {**self.report, key: ['']}])
        invalid.append({**self.report, 'fortalezas': ['x'] * 6})
        for report in invalid:
            with self.assertRaises(ValueError):
                validate_report(report)
            adapter, client = self.adapter([SimpleNamespace(text=json.dumps(report))])
            self.assertEqual(adapter.generate(PAYLOAD, .42, 'MEDIO'), self.report)
            self.assertEqual(client.models.generate_content.call_count, 1)

    def test_invalid_json_blocked_and_empty_response(self):
        for text in ['{', '```json\n{}\n```', '', None, '{"resumen":"a","resumen":"b"}']:
            adapter, client = self.adapter([SimpleNamespace(text=text)])
            self.assertEqual(adapter.generate(PAYLOAD, .42, 'MEDIO'), self.report)
            self.assertEqual(client.models.generate_content.call_count, 1)

    def test_timeout_service_errors_and_bounded_retries(self):
        import httpx
        for error in [TimeoutError('private'), httpx.ReadTimeout('private')]:
            adapter, client = self.adapter([error, error])
            self.assertEqual(adapter.generate(PAYLOAD, .42, 'MEDIO'), self.report)
            self.assertEqual(client.models.generate_content.call_count, 2)
        for code, calls in [(429, 2), (503, 2), (401, 1), (400, 1)]:
            error = RuntimeError('private')
            error.code = code
            adapter, client = self.adapter([error, error])
            self.assertEqual(adapter.generate(PAYLOAD, .42, 'MEDIO'), self.report)
            self.assertEqual(client.models.generate_content.call_count, calls)
        adapter, client = self.adapter([TimeoutError(), SimpleNamespace(text=json.dumps(self.report))])
        self.assertTrue(adapter.generate(PAYLOAD, .42, 'MEDIO')['resumen'].startswith(self.report['resumen']))
        self.assertEqual(client.models.generate_content.call_count, 2)

    def test_sdk_unavailable_and_configuration(self):
        adapter = GeminiReportGenerator(api_key='dummy', model='mock-model',
            client_factory=Mock(side_effect=ImportError('private')))
        self.assertEqual(adapter.generate(PAYLOAD, .42, 'MEDIO'), self.report)
        from google.genai import types
        from google import genai
        with patch.object(genai, 'Client') as factory:
            GeminiReportGenerator._create_client('dummy')
            options = factory.call_args.kwargs['http_options']
            self.assertEqual(options.timeout, 15000)
            self.assertEqual(options.retry_options.attempts, 1)
        types.GenerateContentConfig(response_mime_type='application/json',
                                   response_schema=GEMINI_SCHEMA)

    def test_errors_have_safe_envelope(self):
        app = create_http_app(PredictRiskUseCase(FakePredictor(), FallbackReportGenerator()), 5)
        client = app.test_client()
        for path, kwargs, code in [('/predict', {'json': {}}, 400),
                                   ('/missing', {}, 404)]:
            response = client.post(path, **kwargs)
            self.assertEqual(response.status_code, code)
            self.assertEqual(set(response.json), {'error', 'mensaje'})
            self.assertEqual(response.json['error'], 'Error')
            self.assertIsInstance(response.json['mensaje'], str)
        for error, expected in [(RuntimeError('private'), 500)]:
            client = create_http_app(PredictRiskUseCase(FakePredictor(error=error), FallbackReportGenerator()), 5).test_client()
            response = client.post('/predict', json=PAYLOAD)
            self.assertEqual(response.status_code, expected)
            self.assertEqual(set(response.json), {'error', 'mensaje'})
            self.assertNotIn('private', response.get_data(as_text=True))
        response = create_http_app(None, 0).test_client().post('/predict', json=PAYLOAD)
        self.assertEqual(response.status_code, 503)
        self.assertEqual(set(response.json), {'error', 'mensaje'})

    def test_gemini_schema_strips_additional_properties(self):
        # El esquema enviado a Gemini no debe incluir additionalProperties
        self.assertNotIn('additionalProperties', GEMINI_SCHEMA)
        # REPORT_SCHEMA original permanece intacto
        self.assertIn('additionalProperties', REPORT_SCHEMA)
        self.assertIs(REPORT_SCHEMA['additionalProperties'], False)
        # Los nueve campos, sus tipos y required se conservan
        self.assertEqual(len(GEMINI_SCHEMA['properties']), 9)
        self.assertEqual(len(GEMINI_SCHEMA['required']), 9)
        self.assertEqual(GEMINI_SCHEMA['properties'],
                         {k: v for k, v in REPORT_SCHEMA['properties'].items()})
        self.assertEqual(GEMINI_SCHEMA['required'], REPORT_SCHEMA['required'])
        self.assertEqual(GEMINI_SCHEMA['type'], REPORT_SCHEMA['type'])
        # La clave prohibida no aparece en ningun nivel del esquema enviado
        self.assertNotIn('additionalProperties', GEMINI_SCHEMA)
        self.assertNotIn('additionalProperties',
                         GEMINI_SCHEMA.get('properties', {}))
        # GEMINI_SCHEMA sigue siendo consumible por GenerateContentConfig
        from google.genai import types
        cfg = types.GenerateContentConfig(
            response_mime_type='application/json',
            response_schema=GEMINI_SCHEMA)
        dumped = cfg.model_dump(exclude_none=True, mode='json')
        self.assertNotIn('additionalProperties', dumped['response_schema'])

    def test_validate_report_still_rejects_extra_fields(self):
        # La validacion estricta sigue rechazando campos adicionales
        base = FallbackReportGenerator().generate(PAYLOAD, .42, 'MEDIO')
        with self.assertRaises(ValueError):
            validate_report({**base, 'campo_extra': 'x'})
        with self.assertRaises(ValueError):
            validate_report({k: v for k, v in base.items() if k != 'resumen'})
        self.assertEqual(validate_report(base), base)

    def test_gemini_schema_mutation_does_not_affect_report_schema(self):
        # deepcopy debe aislar las estructuras anidadas de REPORT_SCHEMA
        snapshot = copy.deepcopy(REPORT_SCHEMA)
        try:
            GEMINI_SCHEMA['properties']['resumen']['type'] = 'number'
            GEMINI_SCHEMA['properties']['fortalezas']['maxItems'] = 999
            GEMINI_SCHEMA['required'].append('campo_inventado')
            # REPORT_SCHEMA no debe haberse alterado
            self.assertEqual(REPORT_SCHEMA, snapshot)
            self.assertEqual(REPORT_SCHEMA['properties']['resumen']['type'], 'string')
            self.assertEqual(REPORT_SCHEMA['properties']['fortalezas']['maxItems'], 5)
            self.assertNotIn('campo_inventado', REPORT_SCHEMA['required'])
            # La validacion estricta sigue usando el contrato original
            base = FallbackReportGenerator().generate(PAYLOAD, .42, 'MEDIO')
            self.assertEqual(validate_report(base), base)
        finally:
            # Restaurar el estado del modulo para no contaminar otros tests
            for key, value in snapshot.items():
                GEMINI_SCHEMA[key] = copy.deepcopy(value)
            GEMINI_SCHEMA.pop('additionalProperties', None)
        self.assertEqual(GEMINI_SCHEMA['properties']['resumen']['type'], 'string')
        self.assertNotIn('additionalProperties', GEMINI_SCHEMA)


if __name__ == '__main__':
    unittest.main()

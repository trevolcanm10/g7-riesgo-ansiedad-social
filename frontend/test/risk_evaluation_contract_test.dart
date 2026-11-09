import 'dart:async';
import 'package:ansiedad_ml_app/data/models/resultado_ml_model.dart';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/evaluacion_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/evaluacion_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/reporte_ia.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluation_answers.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';

/// Los 12 indicadores por defecto del cuestionario, todos dentro del rango del DTO.
const _indicadores = <String, double>{
  'sleep_hours': 7,
  'exercise_freq': 3,
  'social_activity': 5,
  'online_stress': 5,
  'family_support': 7,
  'screen_time': 5,
  'academic_stress': 5,
  'diet_quality': 6,
  'self_efficacy': 6,
  'peer_relationship': 7,
  'financial_stress': 4,
  'sleep_quality': 6,
};

/// Respuesta 201 completa del contrato de RiskEvaluation.
Map<String, dynamic> respuestaValida() => {
  'id': 7,
  'userId': 42,
  'anxietyProbability': 0.42,
  'riskLevel': 'MEDIO',
  'explanation': 'Se detectan ciertos niveles de alerta.',
  'recommendations': [
    {
      'id': 1,
      'category': 'MEDIO',
      'title': 'Organiza tus tiempos',
      'description': 'Planifica estudio y descanso.',
    },
  ],
  'aiReport': {
    'summary': 'Resumen de prueba.',
    'strengths': ['Cuentas con apoyo.'],
    'concerningFactors': ['Estres academico.'],
    'recommendations': ['Organizar horarios.'],
    'sevenDayPlan': ['Dia 1: organizar.'],
    'videoTopics': ['Manejo del estres'],
    'readingTopics': ['Habitos de sueno'],
    'priorityIntervention': 'SEGUIMIENTO',
    'motivationalMessage': 'Avanza paso a paso.',
  },
  'createdAt': '2026-10-11T00:00:00Z',
};

/// PHQ-9 con 27 puntos, GAD-7 con 14 puntos y promedio 10 sobre 20.
EvaluationAnswers respuestasCompletas() {
  final answers = EvaluationAnswers()..academicAverage = '10';
  answers.phq9.fillRange(0, 9, 3);
  answers.gad7.fillRange(0, 7, 2);
  return answers;
}

/// Captura lo que Flutter realmente envia por la red.
class Peticion {
  final Uri url;
  final Map<String, String> headers;
  final Map<String, dynamic> body;
  Peticion(this.url, this.headers, this.body);
}

http.Response respuestaJson(Object cuerpo, int status) => http.Response(
  jsonEncode(cuerpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response ok201([Map<String, dynamic>? cuerpo]) =>
    respuestaJson(cuerpo ?? respuestaValida(), 201);

/// Ejecuta el caso de uso completo contra un MockClient y captura la peticion.
Future<({bool ok, String? error, List<Peticion> enviadas})> enviarEvaluacion(
  http.Response Function(Peticion) responder, {
  Map<String, num>? payload,
}) async {
  final enviadas = <Peticion>[];
  var ok = false;
  String? error;
  await http.runWithClient(
    () async {
      final api = ApiService()..setToken('token-de-prueba');
      final repo = EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(api));
      final vm = EvaluacionViewModel(
        EvaluarRiesgoUseCase(repo),
        ObtenerHistorialUseCase(repo),
      );
      ok = await vm.evaluarRiesgo(
        payload ?? respuestasCompletas().toRiskPayload(_indicadores),
      );
      error = vm.error;
      vm.dispose();
    },
    () => MockClient((request) async {
      final body = request.contentLength == 0
          ? <String, dynamic>{}
          : jsonDecode(request.body) as Map<String, dynamic>;
      enviadas.add(Peticion(request.url, request.headers, body));
      return responder(enviadas.last);
    }),
  );
  return (ok: ok, error: error, enviadas: enviadas);
}

void main() {
  group('payload hacia POST /risk-evaluations/', () {
    test('usa la ruta y el puerto de RiskEvaluation, sin /api/v1', () async {
      final r = await enviarEvaluacion((_) => ok201());
      final p = r.enviadas.single;
      expect(p.url.path, '/risk-evaluations/');
      expect(p.url.path.contains('api/v1'), isFalse);
      expect(r.ok, isTrue);
    });

    test('envia el JWT en Authorization y nunca en el cuerpo', () async {
      final r = await enviarEvaluacion((_) => ok201());
      final p = r.enviadas.single;
      expect(p.headers['Authorization'], 'Bearer token-de-prueba');
      expect(p.body.containsKey('token'), isFalse);
    });

    test('contiene los 15 campos camelCase del contrato', () async {
      final r = await enviarEvaluacion((_) => ok201());
      final body = r.enviadas.single.body;
      expect(body.length, 15);
      expect(body.keys.toSet(), {
        'phq9Score',
        'gad7Score',
        'sleepHours',
        'exerciseFreq',
        'socialActivity',
        'onlineStress',
        'gpa',
        'familySupport',
        'screenTime',
        'academicStress',
        'dietQuality',
        'selfEfficacy',
        'peerRelationship',
        'financialStress',
        'sleepQuality',
      });
    });

    test('conserva enteros y deja decimal solo en GPA', () async {
      final r = await enviarEvaluacion((_) => ok201());
      final body = r.enviadas.single.body;
      for (final key in body.keys.where((k) => k != 'gpa')) {
        expect(body[key], isA<int>(), reason: key);
      }
      expect(body['gpa'], isA<double>());
    });

    test('reutiliza los totales ya calculados de PHQ-9 y GAD-7', () async {
      final r = await enviarEvaluacion((_) => ok201());
      final body = r.enviadas.single.body;
      expect(body['phq9Score'], 27);
      expect(body['gad7Score'], 14);
    });

    test('convierte el promedio sobre 20 a GPA sobre 5', () async {
      for (final caso in {
        '0': 0.0,
        '10': 2.5,
        '20': 5.0,
        '15.2': 3.8,
      }.entries) {
        final r = await enviarEvaluacion(
          (_) => ok201(),
          payload: (respuestasCompletas()..academicAverage = caso.key)
              .toRiskPayload(_indicadores),
        );
        expect(r.enviadas.single.body['gpa'], caso.value, reason: caso.key);
      }
    });
  });
  group('lectura de la respuesta 201', () {
    Future<
      ({double prob, String nivel, String? exp, int recs, ReporteIA? reporte})
    >
    leer() {
      return http.runWithClient(() async {
        final api = ApiService()..setToken('token-de-prueba');
        final repo = EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(api));
        final result = await EvaluarRiesgoUseCase(repo)(
          respuestasCompletas().toRiskPayload(_indicadores),
        );
        return (
          prob: result.resultado.probabilidadAnsiedad,
          nivel: result.resultado.nivelRiesgo,
          exp: result.explicacion,
          recs: result.recomendaciones.length,
          reporte: result.resultado.reporteIA,
        );
      }, () => MockClient((_) async => ok201()));
    }

    test('mapea probabilidad, nivel, explicacion y recomendaciones', () async {
      final r = await leer();
      expect(r.prob, 0.42);
      expect(r.nivel, 'MEDIO');
      expect(r.exp, 'Se detectan ciertos niveles de alerta.');
      expect(r.recs, 1);
    });

    test('conserva las nueve secciones del aiReport', () async {
      final r = await leer();
      final reporte = r.reporte;
      expect(reporte, isNotNull);
      expect(reporte!.resumen, 'Resumen de prueba.');
      expect(reporte.fortalezas, ['Cuentas con apoyo.']);
      expect(reporte.factoresPreocupantes, ['Estres academico.']);
      expect(reporte.recomendaciones, ['Organizar horarios.']);
      expect(reporte.plan7Dias, ['Dia 1: organizar.']);
      expect(reporte.temasVideos, ['Manejo del estres']);
      expect(reporte.temasLectura, ['Habitos de sueno']);
      expect(reporte.prioridadIntervencion, 'SEGUIMIENTO');
      expect(reporte.mensajeMotivacional, 'Avanza paso a paso.');
    });
  });
  group('respuestas incompletas o invalidas', () {
    Map<String, dynamic> sinCampo(String key) => respuestaValida()..remove(key);

    for (final campo in [
      'id',
      'userId',
      'createdAt',
      'aiReport',
      'anxietyProbability',
      'riskLevel',
      'explanation',
      'recommendations',
    ]) {
      test('sin $campo se rechaza en vez de inventar un resultado', () async {
        final r = await enviarEvaluacion((_) => ok201(sinCampo(campo)));
        expect(r.ok, isFalse);
        expect(r.error, isNotNull);
      });
    }

    test('nivel de riesgo no valido se rechaza', () async {
      for (final nivel in ['INVENTADO', 'bajo', 7]) {
        final r = await enviarEvaluacion(
          (_) => ok201(respuestaValida()..['riskLevel'] = nivel),
        );
        expect(r.ok, isFalse, reason: '$nivel');
      }
    });

    test('probabilidad fuera de 0..1 se rechaza', () async {
      for (final valor in [-0.1, 1.5, 42]) {
        final r = await enviarEvaluacion(
          (_) => ok201(respuestaValida()..['anxietyProbability'] = valor),
        );
        expect(r.ok, isFalse, reason: '$valor');
      }
    });

    test('cuerpo vacio se rechaza', () async {
      final r = await enviarEvaluacion((_) => http.Response('', 201));
      expect(r.ok, isFalse);
    });

    test('recomendacion incompleta se rechaza', () async {
      final r = await enviarEvaluacion(
        (_) => ok201(
          respuestaValida()
            ..['recommendations'] = [
              {'id': 1, 'category': 'MEDIO'},
            ],
        ),
      );
      expect(r.ok, isFalse);
    });

    test('aiReport incompleto se rechaza', () async {
      final r = await enviarEvaluacion(
        (_) => ok201(
          respuestaValida()..['aiReport'] = {'summary': 'Solo resumen.'},
        ),
      );
      expect(r.ok, isFalse);
    });

    test('nunca deriva en probabilidad 0 ni riesgo BAJO', () async {
      final r = await enviarEvaluacion((_) => ok201(sinCampo('riskLevel')));
      expect(r.ok, isFalse);
      expect(r.error, isNot(contains('BAJO')));
    });
  });

  group('errores y concurrencia', () {
    test(
      '401 de evaluacion limpia estado sin un segundo aviso local',
      () async {
        await http.runWithClient(
          () async {
            final api = ApiService()..setToken('fixture');
            final repo = EvaluacionRepositoryImpl(
              EvaluacionRemoteDataSource(api),
            );
            final vm = EvaluacionViewModel(
              EvaluarRiesgoUseCase(repo),
              ObtenerHistorialUseCase(repo),
            );
            var invalidations = 0;
            api.onUnauthorized = () async {
              invalidations++;
              vm.limpiarSesion();
            };
            expect(
              await vm.evaluarRiesgo(
                respuestasCompletas().toRiskPayload(_indicadores),
              ),
              isFalse,
            );
            expect(invalidations, 1);
            expect(vm.error, isNull);
            expect(vm.ultimoResultado, isNull);
            expect(vm.isLoading, isFalse);
            vm.dispose();
          },
          () => MockClient(
            (_) async => respuestaJson({'message': 'expired'}, 401),
          ),
        );
      },
    );
    for (final status in [200, 202, 204, 400, 401, 403, 404, 500]) {
      test('HTTP $status no publica un resultado', () async {
        final result = await enviarEvaluacion(
          (_) => respuestaJson(respuestaValida(), status),
        );
        expect(result.ok, isFalse);
        expect(result.error, isNotNull);
        if (status == 403) expect(result.error, isNot(contains('expiro')));
      });
    }
    for (final fault in [
      TimeoutException('test'),
      http.ClientException('test'),
    ]) {
      test(
        'error de transporte ${fault.runtimeType} conserva posibilidad de reintento',
        () async {
          final api = ApiService();
          final vm = EvaluacionViewModel(
            EvaluarRiesgoUseCase(
              EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(api)),
            ),
            ObtenerHistorialUseCase(
              EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(api)),
            ),
          );
          await http.runWithClient(() async {
            expect(
              await vm.evaluarRiesgo(
                respuestasCompletas().toRiskPayload(_indicadores),
              ),
              isFalse,
            );
            expect(vm.isLoading, isFalse);
            expect(vm.error, isNotNull);
          }, () => MockClient((_) async => throw fault));
          vm.dispose();
        },
      );
    }
    test('dos envios simultaneos producen una sola peticion', () async {
      final pending = Completer<http.Response>();
      var calls = 0;
      await http.runWithClient(
        () async {
          final repo = EvaluacionRepositoryImpl(
            EvaluacionRemoteDataSource(ApiService()),
          );
          final vm = EvaluacionViewModel(
            EvaluarRiesgoUseCase(repo),
            ObtenerHistorialUseCase(repo),
          );
          final payload = respuestasCompletas().toRiskPayload(_indicadores);
          final first = vm.evaluarRiesgo(payload);
          expect(await vm.evaluarRiesgo(payload), isFalse);
          await Future<void>.delayed(Duration.zero);
          expect(calls, 1);
          pending.complete(ok201());
          expect(await first, isTrue);
          vm.dispose();
        },
        () => MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
    });
    test(
      'rechaza indicadores faltantes, decimales, no finitos y fuera de rango',
      () {
        for (final field in _indicadores.keys) {
          final missing = Map<String, double>.of(_indicadores)..remove(field);
          expect(
            () => respuestasCompletas().toRiskPayload(missing),
            throwsFormatException,
          );
          for (final value in [double.nan, double.infinity, -1.0, 99.0, 3.5]) {
            final invalid = Map<String, double>.of(_indicadores)
              ..[field] = value;
            expect(
              () => respuestasCompletas().toRiskPayload(invalid),
              throwsFormatException,
            );
          }
        }
      },
    );
    test('mapea identidad y fecha sin valores inventados', () {
      final result = ResultadoMlModel.fromRiskEvaluation(respuestaValida());
      expect(result.idEvaluacion, 7);
      expect(result.idUsuario, 42);
      expect(result.fechaPrediccion, '2026-10-11T00:00:00Z');
      for (final change in <Map<String, dynamic>>[
        {'id': 0},
        {'userId': 0},
        {'createdAt': 'invalid'},
        {'anxietyProbability': double.nan},
        {'explanation': ''},
        {
          'recommendations': [null],
        },
        {'aiReport': null},
      ]) {
        expect(
          () => ResultadoMlModel.fromRiskEvaluation({
            ...respuestaValida(),
            ...change,
          }),
          throwsFormatException,
        );
      }
    });
  });
}

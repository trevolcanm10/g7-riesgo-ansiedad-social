import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/evaluacion_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/evaluacion_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/medico_viewmodel.dart';
import 'package:ansiedad_ml_app/domain/repositories/medico_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_estadisticas_medico_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_pacientes_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_evaluaciones_recientes_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/session_gate.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/login_screen.dart';
import 'fake_session_store.dart';

const _user = {
  'id': 1,
  'names': 'Ana',
  'surnames': 'Perez',
  'code': '001',
  'email': 'ana@example.com',
  'school': 'Sistemas',
  'cycle': 9,
  'createdAt': '2026-10-11T00:00:00Z',
};

class CountingStore extends FakeSessionStore {
  int deletes = 0;
  @override
  Future<void> delete() async {
    deletes++;
    await super.delete();
  }
}

class PendingMedico implements MedicoRepository {
  final stats = Completer<Map<String, dynamic>>();
  final patients = Completer<List<Map<String, dynamic>>>();
  final recent = Completer<List<Map<String, dynamic>>>();
  @override
  Future<Map<String, dynamic>> obtenerEstadisticas() => stats.future;
  @override
  Future<List<Map<String, dynamic>>> obtenerPacientes() => patients.future;
  @override
  Future<List<Map<String, dynamic>>> obtenerEvaluacionesRecientes() =>
      recent.future;
}

AuthViewModel authFor(ApiService api, FakeSessionStore store) {
  final repo = AuthRepositoryImpl(AuthRemoteDataSource(api), store);
  final auth = AuthViewModel(
    LoginUseCase(repo),
    RegisterUseCase(repo),
    LogoutUseCase(repo),
  );
  api.onUnauthorized = auth.invalidarSesion;
  return auth;
}

Future<void> fail(Future<dynamic> future) async {
  await expectLater(future, throwsA(isA<ApiException>()));
}

// Respuesta 201 completa de POST /risk-evaluations/ (contrato camelCase).
const riskEvaluationResponse = <String, dynamic>{
  'id': 7,
  'userId': 1,
  'anxietyProbability': 0.42,
  'riskLevel': 'MEDIO',
  'explanation': 'test',
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

class EvaluationApi extends ApiService {
  Completer<Map<String, dynamic>>? pendingResult;
  Completer<List<dynamic>>? pendingHistory;
  @override
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    int? expectedStatus,
  }) async => pendingResult == null
      ? riskEvaluationResponse
      : await pendingResult!.future;
  @override
  Future<List<dynamic>> getList(String url) async => pendingHistory == null
      ? [
          {'id_evaluacion': 1, 'id_usuario': 1},
        ]
      : await pendingHistory!.future;
}

EvaluacionViewModel evaluationFor(EvaluationApi api) {
  final repo = EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(api));
  return EvaluacionViewModel(
    EvaluarRiesgoUseCase(repo),
    ObtenerHistorialUseCase(repo),
  );
}

void main() {
  test(
    'estado médico descarta estadísticas, pacientes y evaluaciones antiguos',
    () async {
      final repo = PendingMedico();
      final vm = MedicoViewModel(
        ObtenerEstadisticasMedicoUseCase(repo),
        ObtenerPacientesUseCase(repo),
        ObtenerEvaluacionesRecientesUseCase(repo),
      );
      final pending = vm.cargarTodo();
      vm.limpiarSesion();
      repo.stats.complete({'total': 1});
      repo.patients.complete([
        {'id': 1},
      ]);
      repo.recent.complete([
        {'id': 1},
      ]);
      await pending;
      expect(vm.estadisticas, isNull);
      expect(vm.pacientes, isEmpty);
      expect(vm.evaluacionesRecientes, isEmpty);
      expect(vm.isLoadingStats, isFalse);
      expect(vm.isLoadingPacientes, isFalse);
      expect(vm.isLoadingRecientes, isFalse);
      vm.dispose();
    },
  );
  test('errores antiguos no contaminan una sesión nueva', () async {
    final api = EvaluationApi()
      ..pendingResult = Completer()
      ..pendingHistory = Completer();
    final vm = evaluationFor(api);
    final evaluation = vm.evaluarRiesgo({});
    final history = vm.obtenerHistorial();
    vm.limpiarSesion();
    api.pendingResult!.completeError(Exception('test'));
    api.pendingHistory!.completeError(Exception('test'));
    expect(await evaluation, isFalse);
    await history;
    expect(vm.error, isNull);
    expect(vm.isLoading, isFalse);
    vm.dispose();
  });
  test(
    '401 mantiene el manejo de fallo de borrado seguro y reintento',
    () async {
      final api = ApiService();
      final store = CountingStore();
      final auth = authFor(api, store);
      await http.runWithClient(
        () async {
          await auth.login('ana@example.com', 'dummy');
          store.failDelete = true;
          await fail(api.get('http://local/a'));
          expect(auth.isAuthenticated, isFalse);
          expect(auth.logoutFailed, isTrue);
          expect(store.session != null, isTrue);
          store.failDelete = false;
          expect(await auth.logout(), isTrue);
          expect(store.session == null, isTrue);
        },
        () => MockClient(
          (request) async => request.method == 'POST'
              ? http.Response(
                  jsonEncode({'accessToken': 'test', 'user': _user}),
                  200,
                )
              : http.Response('{}', 401),
        ),
      );
      auth.dispose();
    },
  );
  final methods = <String, Future<dynamic> Function(ApiService)>{
    'GET': (api) => api.get('http://local/protected'),
    'LIST': (api) => api.getList('http://local/protected'),
    'POST': (api) => api.post('http://local/protected'),
    'PUT': (api) => api.put('http://local/protected'),
    'DELETE': (api) => api.delete('http://local/protected'),
  };
  for (final entry in methods.entries) {
    test('401 protegido ${entry.key} invalida sesión', () async {
      final api = ApiService()..setToken('test');
      int notifications = 0;
      api.onUnauthorized = () async {
        notifications++;
      };
      await http.runWithClient(
        () async => fail(entry.value(api)),
        () => MockClient((_) async => http.Response('{}', 401)),
      );
      expect(notifications, 1);
    });
  }
  test('login y registro públicos no invalidan una sesión vigente', () async {
    final api = ApiService()..setToken('test');
    int notifications = 0;
    api.onUnauthorized = () async {
      notifications++;
    };
    await http.runWithClient(
      () async {
        await fail(api.post('http://local/users/login', withAuth: false));
        await fail(api.post('http://local/users', withAuth: false));
      },
      () => MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), isFalse);
        return http.Response('{}', 401);
      }),
    );
    expect(notifications, 0);
  });
  test('dos 401 simultáneos notifican y borran una sola vez', () async {
    final api = ApiService();
    final store = CountingStore();
    final auth = authFor(api, store);
    await http.runWithClient(
      () async {
        await auth.login('ana@example.com', 'dummy');
        final before = store.deletes;
        await Future.wait([
          fail(api.get('http://local/a')),
          fail(api.getList('http://local/b')),
        ]);
        expect(store.deletes, before + 1);
        expect(store.session == null, isTrue);
        expect(auth.isAuthenticated, isFalse);
        expect(auth.invalidatedBy401, isTrue);
      },
      () => MockClient(
        (request) async => request.method == 'POST'
            ? http.Response(
                jsonEncode({'accessToken': 'test', 'user': _user}),
                200,
              )
            : http.Response('{}', 401),
      ),
    );
    auth.dispose();
  });
  for (final replacement in ['new-test', 'same-test']) {
    test('401 antiguo ignora sesión posterior $replacement', () async {
      final api = ApiService()..setToken('same-test');
      int notifications = 0;
      api.onUnauthorized = () async {
        notifications++;
      };
      final response = Completer<http.Response>();
      final started = Completer<void>();
      await http.runWithClient(
        () async {
          final request = fail(api.get('http://local/a'));
          await started.future;
          api.setToken(replacement);
          response.complete(http.Response('{}', 401));
          await request;
        },
        () => MockClient((_) {
          started.complete();
          return response.future;
        }),
      );
      expect(notifications, 0);
    });
  }
  for (final code in [403, 404, 500]) {
    test('HTTP $code no provoca logout', () async {
      final api = ApiService()..setToken('test');
      int notifications = 0;
      api.onUnauthorized = () async {
        notifications++;
      };
      await http.runWithClient(
        () async => fail(api.get('http://local/a')),
        () => MockClient((_) async => http.Response('{}', code)),
      );
      expect(notifications, 0);
    });
  }
  test('timeout y conexión no provocan logout', () async {
    for (final error in [
      TimeoutException('test'),
      http.ClientException('test'),
    ]) {
      final api = ApiService()..setToken('test');
      int notifications = 0;
      api.onUnauthorized = () async {
        notifications++;
      };
      await http.runWithClient(
        () async => expectLater(api.get('http://local/a'), throwsA(anything)),
        () => MockClient((_) async => throw error),
      );
      expect(notifications, 0);
    }
  });
  test('logout y cambio de usuario limpian resultado e historial', () async {
    final evaluation = evaluationFor(EvaluationApi());
    final api = ApiService();
    final auth = authFor(api, FakeSessionStore());
    auth.onSessionReset = evaluation.limpiarSesion;
    await http.runWithClient(
      () async {
        await auth.login('ana@example.com', 'dummy');
        await evaluation.evaluarRiesgo({});
        await evaluation.obtenerHistorial();
        expect(evaluation.historial, isNotEmpty);
        expect(evaluation.probabilidad, isNotNull);
        await auth.logout();
        expect(evaluation.historial, isEmpty);
        expect(evaluation.probabilidad, isNull);
        expect(evaluation.ultimoResultado, isNull);
        await evaluation.evaluarRiesgo({});
        await evaluation.obtenerHistorial();
        await auth.login('ana@example.com', 'dummy');
        expect(evaluation.historial, isEmpty);
        expect(evaluation.probabilidad, isNull);
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({'accessToken': 'test', 'user': _user}),
          200,
        ),
      ),
    );
    auth.dispose();
    evaluation.dispose();
  });
  test(
    'respuestas antiguas de evaluación e historial no recargan estado',
    () async {
      final api = EvaluationApi()
        ..pendingResult = Completer()
        ..pendingHistory = Completer();
      final vm = evaluationFor(api);
      final result = vm.evaluarRiesgo({});
      final history = vm.obtenerHistorial();
      vm.limpiarSesion();
      api.pendingResult!.complete(riskEvaluationResponse);
      api.pendingHistory!.complete([
        {'id_evaluacion': 1},
      ]);
      expect(await result, isFalse);
      await history;
      expect(vm.historial, isEmpty);
      expect(vm.probabilidad, isNull);
      expect(vm.isLoading, isFalse);
      expect(vm.error, isNull);
      vm.dispose();
    },
  );
  testWidgets('401 limpia evaluaciones y SessionGate bloquea ruta protegida', (
    tester,
  ) async {
    final api = ApiService();
    final auth = authFor(api, FakeSessionStore());
    final evaluation = evaluationFor(EvaluationApi());
    auth.onSessionReset = evaluation.limpiarSesion;
    await http.runWithClient(
      () async {
        await auth.login('ana@example.com', 'dummy');
        await evaluation.obtenerHistorial();
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: auth,
            child: const MaterialApp(
              home: SessionProtected(child: Text('Privado')),
            ),
          ),
        );
        expect(find.text('Privado'), findsOneWidget);
        await fail(api.get('http://local/protected'));
        await tester.pumpAndSettle();
        expect(find.text('Privado'), findsNothing);
        expect(find.byType(LoginScreen), findsOneWidget);
        expect(evaluation.historial, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
      () => MockClient(
        (request) async => request.method == 'POST'
            ? http.Response(
                jsonEncode({'accessToken': 'test', 'user': _user}),
                200,
              )
            : http.Response('{}', 401),
      ),
    );
    auth.dispose();
    evaluation.dispose();
  });
}

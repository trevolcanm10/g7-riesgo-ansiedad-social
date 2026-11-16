import 'package:ansiedad_ml_app/core/app_colors.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluacion.dart';
import 'package:ansiedad_ml_app/domain/entities/recomendacion.dart';
import 'package:ansiedad_ml_app/domain/entities/resultado_ml.dart';
import 'package:ansiedad_ml_app/domain/entities/usuario.dart';
import 'package:ansiedad_ml_app/domain/repositories/auth_repository.dart';
import 'package:ansiedad_ml_app/domain/repositories/evaluacion_repository.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/home/home_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _AuthRepo implements AuthRepository {
  @override
  Future<({String token, Usuario usuario})> login({
    required String correo,
    required String contrasena,
  }) async => (
    token: 'widget-test-token',
    usuario: const Usuario(
      idUsuario: 42,
      nombres: 'Lucía',
      apellidos: 'Paredes',
      codigo: '001',
      correo: 'lucia@example.test',
      escuela: 'Sistemas',
      ciclo: 8,
      createdAt: '2026-11-13T00:00:00Z',
    ),
  );
  @override
  Future<void> logout() async {}
  @override
  Future<void> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {}
  @override
  Future<({String token, Usuario usuario})?> restaurarSesion() async => null;
}

class _EvaluationRepo implements EvaluacionRepository {
  _EvaluationRepo({this.withHistory = false});
  final bool withHistory;
  @override
  Future<List<Evaluacion>> obtenerHistorial() async => withHistory
      ? [
          Evaluacion(
            idEvaluacion: 1,
            idUsuario: 42,
            phq9Score: 0,
            gad7Score: 0,
            sleepHours: 8,
            exerciseFreq: 3,
            socialActivity: 1,
            onlineStress: 0,
            gpa: 15,
            familySupport: 1,
            screenTime: 2,
            academicStress: 0,
            dietQuality: 1,
            selfEfficacy: 1,
            peerRelationship: 1,
            financialStress: 0,
            sleepQuality: 1,
          ),
        ]
      : [];
  @override
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables) => throw UnimplementedError();
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  Size size, {
  bool withHistory = false,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final authRepo = _AuthRepo();
  final auth = AuthViewModel(
    LoginUseCase(authRepo),
    RegisterUseCase(authRepo),
    LogoutUseCase(authRepo),
  );
  expect(await auth.login('lucia@example.test', 'unused'), isTrue);
  final evaluations = _EvaluationRepo(withHistory: withHistory);
  final evaluation = EvaluacionViewModel(
    EvaluarRiesgoUseCase(evaluations),
    ObtenerHistorialUseCase(evaluations),
  );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: auth),
        ChangeNotifierProvider<EvaluacionViewModel>.value(value: evaluation),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: const HomeScreen(),
        routes: {
          '/evaluacion': (_) =>
              const Scaffold(body: Text('Flujo de evaluación')),
          '/agenda': (_) => const Scaffold(body: Text('Módulo Agenda')),
          '/historial': (_) => const Scaffold(body: Text('Historial real')),
          '/perfil': (_) => const Scaffold(body: Text('Perfil real')),
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('dashboard date uses the actual calendar day in Spanish', () {
    expect(
      formatStudentDashboardDate(DateTime(2026, 5, 26)),
      'Martes, 26 de mayo',
    );
  });

  testWidgets('mobile uses authenticated name, current date and real routes', (
    tester,
  ) async {
    await _pumpDashboard(tester, const Size(375, 667));
    expect(find.textContaining('Lucía'), findsOneWidget);
    expect(find.textContaining('Ana'), findsNothing);
    expect(find.textContaining('26 de mayo'), findsNothing);
    expect(find.text('¿Cómo te sientes hoy?'), findsOneWidget);
    expect(find.text('Orientación UNAYOE'), findsOneWidget);
    expect(find.text('Agenda Académica'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Iniciar mi primera evaluación'));
    await tester.pumpAndSettle();
    expect(find.text('Flujo de evaluación'), findsOneWidget);
  });

  testWidgets('wide layout keeps agenda navigation and no overflow', (
    tester,
  ) async {
    await _pumpDashboard(tester, const Size(1200, 900));
    await tester.ensureVisible(find.text('Agenda Académica'));
    await tester.tap(find.text('Agenda Académica'));
    await tester.pumpAndSettle();
    expect(find.text('Módulo Agenda'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history keeps one Figma dashboard and one evaluation action', (
    tester,
  ) async {
    await _pumpDashboard(tester, const Size(375, 667), withHistory: true);
    expect(find.text('TU ESPACIO SEGURO'), findsOneWidget);
    expect(find.text('Iniciar nueva evaluación'), findsOneWidget);
    expect(find.text('Iniciar Nueva Evaluación'), findsNothing);
    expect(find.text('Historial'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

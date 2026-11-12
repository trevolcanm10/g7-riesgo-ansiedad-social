import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:ansiedad_ml_app/core/api_gateway_config.dart';
import 'package:ansiedad_ml_app/core/constants.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/evaluacion_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/orientacion_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/data/repositories/evaluacion_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluacion.dart';
import 'package:ansiedad_ml_app/domain/entities/solicitud_orientacion.dart';
import 'package:ansiedad_ml_app/domain/usecases/evaluar_riesgo_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/obtener_historial_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/orientacion/orientacion_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/evaluacion_viewmodel.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/orientacion_viewmodel.dart';

import 'fake_session_store.dart';

class _FakeApiService extends ApiService {
  String? lastPostUrl;
  Map<String, dynamic>? lastPostBody;
  bool? lastWithAuth;
  ApiException? errorToThrow;
  Map<String, dynamic> postResponse = {
    'id': 1,
    'estudiante_id': 101,
    'mensaje': 'Consulta académica',
    'comparte_evaluacion_riesgo': false,
    'evaluacion_riesgo_id': null,
    'tema_sugerido': 'academico',
    'prioridad_sugerida': 'media',
    'urgencia_detectada': false,
    'estado': 'pendiente',
    'tema_confirmado': null,
    'prioridad_confirmada': null,
    'respuesta_escrita': null,
    'atendido_por': null,
    'fecha_creacion': '2026-11-12T10:00:00Z',
    'fecha_atencion': null,
  };
  List<dynamic> listResponse = [];

  @override
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    int? expectedStatus,
    bool withAuth = true,
  }) async {
    lastPostUrl = url;
    lastPostBody = body;
    lastWithAuth = withAuth;
    if (errorToThrow != null) throw errorToThrow!;
    return postResponse;
  }

  @override
  Future<List<dynamic>> getList(String url, {bool withAuth = true}) async {
    lastWithAuth = withAuth;
    if (errorToThrow != null) throw errorToThrow!;
    return listResponse;
  }
}

class _FakeAuthViewModel extends AuthViewModel {
  bool authenticated;
  int? userId;

  _FakeAuthViewModel({required this.authenticated, this.userId})
      : super(
          LoginUseCase(
            AuthRepositoryImpl(
              AuthRemoteDataSource(ApiService()),
              FakeSessionStore(),
            ),
          ),
          RegisterUseCase(
            AuthRepositoryImpl(
              AuthRemoteDataSource(ApiService()),
              FakeSessionStore(),
            ),
          ),
          LogoutUseCase(
            AuthRepositoryImpl(
              AuthRemoteDataSource(ApiService()),
              FakeSessionStore(),
            ),
          ),
        );

  @override
  bool get isAuthenticated => authenticated;

  @override
  int? get idUsuario => userId;
}

class _FakeEvaluacionViewModel extends EvaluacionViewModel {
  List<Evaluacion> fakeHistorial;

  _FakeEvaluacionViewModel(this.fakeHistorial)
      : super(
          EvaluarRiesgoUseCase(
            EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(ApiService())),
          ),
          ObtenerHistorialUseCase(
            EvaluacionRepositoryImpl(EvaluacionRemoteDataSource(ApiService())),
          ),
        );

  @override
  List<Evaluacion> get historial => fakeHistorial;
}

Evaluacion _dummyEval(int id, int userId) => Evaluacion(
      idEvaluacion: id,
      idUsuario: userId,
      phq9Score: 8,
      gad7Score: 10,
      sleepHours: 6.5,
      exerciseFreq: 2,
      socialActivity: 3,
      onlineStress: 4,
      gpa: 15,
      familySupport: 4,
      screenTime: 5,
      academicStress: 7,
      dietQuality: 3,
      selfEfficacy: 3,
      peerRelationship: 4,
      financialStress: 2,
      sleepQuality: 3,
    );

void main() {
  test('ApiGatewayConfig expone orientacionOrigin con prefijo /o', () {
    const gw = ApiGatewayConfig(
      baseUrl: 'https://apim-g7-riesgo-ansiedad.azure-api.net/',
      subscriptionKey: 'fake-key',
    );
    expect(gw.orientacionOrigin, '${gw.origin}/o');
    expect(
      AppConstants.orientacionSolicitudes,
      endsWith('/api/v1/orientacion/solicitudes'),
    );
  });

  test('SolicitudOrientacion parsea estudiante_id y atendido_por enteros', () {
    final sol = SolicitudOrientacion.fromJson({
      'id': 9,
      'estudiante_id': 101,
      'mensaje': 'Necesito apoyo',
      'comparte_evaluacion_riesgo': true,
      'evaluacion_riesgo_id': 55,
      'tema_sugerido': 'academico',
      'prioridad_sugerida': 'alta',
      'urgencia_detectada': true,
      'estado': 'atendida',
      'atendido_por': 77,
      'respuesta_escrita': 'Te orientamos hoy',
    });
    expect(sol.estudianteId, 101);
    expect(sol.atendidoPor, 77);
    expect(sol.evaluacionRiesgoId, 55);
  });

  test('OrientacionRemoteDataSource usa JWT y no envía estudiante_id', () async {
    final api = _FakeApiService();
    final ds = OrientacionRemoteDataSource(api);

    final resp = await ds.enviarSolicitud(
      mensaje: 'Dudas sobre examen final',
      comparteEvaluacion: true,
      evaluacionRiesgoId: 44,
    );

    expect(api.lastWithAuth, isTrue);
    expect(api.lastPostBody?.containsKey('estudiante_id'), isFalse);
    expect(api.lastPostBody?['evaluacion_riesgo_id'], 44);
    expect(resp.solicitud.id, 1);

    api.errorToThrow = ApiException(statusCode: 401, mensaje: 'Unauthorized');
    await expectLater(
      ds.enviarSolicitud(mensaje: 'Hola', comparteEvaluacion: false),
      throwsA(
        predicate<Exception>((e) => e.toString().contains('sesión expiró')),
      ),
    );
  });

  test('OrientacionViewModel exige autenticación real y valida evaluación', () async {
    final api = _FakeApiService();
    final ds = OrientacionRemoteDataSource(api);

    // Usuario no autenticado: no cae en fallback "Estudiante"
    final unauthVM = OrientacionViewModel(
      ds,
      _FakeAuthViewModel(authenticated: false, userId: null),
      _FakeEvaluacionViewModel([]),
    );
    expect(await unauthVM.enviarSolicitud('Hola', false), isFalse);
    expect(unauthVM.error, contains('iniciar sesión'));
    expect(api.lastPostUrl, isNull);

    // Usuario autenticado sin evaluaciones no puede compartir evaluación
    final authNoEvalVM = OrientacionViewModel(
      ds,
      _FakeAuthViewModel(authenticated: true, userId: 101),
      _FakeEvaluacionViewModel([]),
    );
    expect(authNoEvalVM.puedeCompartirEvaluacion, isFalse);
    expect(await authNoEvalVM.enviarSolicitud('Hola', true), isFalse);
    expect(authNoEvalVM.error, contains('evaluación de riesgo'));

    // Usuario autenticado con evaluación real envía su idEvaluacion real y detecta alerta
    api.postResponse = {
      'id': 12,
      'estudiante_id': 101,
      'mensaje': 'No me siento seguro en casa',
      'comparte_evaluacion_riesgo': true,
      'evaluacion_riesgo_id': 88,
      'tema_sugerido': 'familiar',
      'prioridad_sugerida': 'alta',
      'urgencia_detectada': true,
      'estado': 'pendiente',
      'alertas_urgencia': {
        'coincidencias': ['no_me_siento_seguro: no me siento seguro'],
        'lineas_ayuda': ['Línea 113 MINSA (Opción 5)', 'SAMU: 106'],
      },
    };
    final vm = OrientacionViewModel(
      ds,
      _FakeAuthViewModel(authenticated: true, userId: 101),
      _FakeEvaluacionViewModel([_dummyEval(88, 101)]),
    );
    expect(vm.puedeCompartirEvaluacion, isTrue);
    expect(await vm.enviarSolicitud('No me siento seguro en casa', true), isTrue);
    expect(api.lastPostBody?['evaluacion_riesgo_id'], 88);
    expect(vm.ultimaAlerta?.lineasAyuda, contains('SAMU: 106'));
    expect(vm.historial.length, 1);

    vm.limpiarSesion();
    expect(vm.historial, isEmpty);
    expect(vm.ultimaAlerta, isNull);
  });

  testWidgets('OrientacionScreen deshabilita switch si no hay evaluación previa', (
    tester,
  ) async {
    final api = _FakeApiService();
    final vm = OrientacionViewModel(
      OrientacionRemoteDataSource(api),
      _FakeAuthViewModel(authenticated: true, userId: 101),
      _FakeEvaluacionViewModel([]),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<OrientacionViewModel>.value(
        value: vm,
        child: const MaterialApp(home: OrientacionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Orientación Confidencial'), findsOneWidget);
    final switchWidget = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchWidget.onChanged, isNull);
    expect(
      find.text('Realiza primero una evaluación de riesgo para poder adjuntarla.'),
      findsOneWidget,
    );
  });
}

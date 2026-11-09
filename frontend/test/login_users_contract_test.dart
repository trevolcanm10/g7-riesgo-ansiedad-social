import 'fake_session_store.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/core/constants.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/models/usuario_model.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/login_screen.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';

const _user = <String, dynamic>{
  'id': 42,
  'names': 'Ana Maria',
  'surnames': 'Perez Ruiz',
  'code': '0012345',
  'email': 'ana@example.com',
  'school': 'Ingeniería de Sistemas',
  'cycle': 9,
  'createdAt': '2026-10-10T12:00:00.000Z',
};

// Token de prueba opaco, sin JWT real. Ninguna prueba realiza HTTP.
class _FakeApi extends ApiService {
  Map<String, dynamic> response = {
    'message': 'Inicio de sesión exitoso',
    'user': Map<String, dynamic>.from(_user),
    'accessToken': 'test-session',
  };
  Object? failure;
  String? url;
  Map<String, dynamic>? body;
  bool? withAuth;
  bool hasToken = false;
  int calls = 0;
  Completer<void>? wait;

  @override
  void setToken(String? token) {
    hasToken = token != null;
    super.setToken(token);
  }

  @override
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    int? expectedStatus,
  }) async {
    this.url = url;
    this.body = body;
    this.withAuth = withAuth;
    calls++;
    if (wait != null) await wait!.future;
    if (failure != null) throw failure!;
    return response;
  }
}

AuthViewModel _vm(_FakeApi api) {
  final repository = AuthRepositoryImpl(
    AuthRemoteDataSource(api),
    FakeSessionStore(),
  );
  return AuthViewModel(
    LoginUseCase(repository),
    RegisterUseCase(repository),
    LogoutUseCase(repository),
  );
}

void main() {
  test(
    'ApiService envía Bearer después del login y lo elimina al salir',
    () async {
      final api = ApiService();
      final vm = AuthViewModel(
        LoginUseCase(
          AuthRepositoryImpl(AuthRemoteDataSource(api), FakeSessionStore()),
        ),
        RegisterUseCase(
          AuthRepositoryImpl(AuthRemoteDataSource(api), FakeSessionStore()),
        ),
        LogoutUseCase(
          AuthRepositoryImpl(AuthRemoteDataSource(api), FakeSessionStore()),
        ),
      );
      final authorizationPresent = <bool>[];
      await http.runWithClient(
        () async {
          expect(await vm.login('ana@example.com', 'dummy-input'), isTrue);
          await api.get('http://localhost/users/me');
          await vm.logout();
          await api.get('http://localhost/users/me');
        },
        () => MockClient((request) async {
          final header = request.headers['Authorization'];
          if (request.method == 'POST') {
            expect(header == null, isTrue);
            return http.Response(
              jsonEncode({
                'message': 'Inicio de sesión exitoso',
                'user': _user,
                'accessToken': 'test-session',
              }),
              200,
            );
          }
          authorizationPresent.add(header == 'Bearer test-session');
          return http.Response('{}', 200);
        }),
      );
      expect(authorizationPresent, [true, false]);
      vm.dispose();
    },
  );

  test('login usa el endpoint y request exactos sin Bearer', () async {
    final api = _FakeApi();
    final vm = _vm(api);
    expect(await vm.login(' ana@example.com ', 'dummy-input'), isTrue);
    expect(api.url, '${AppConstants.baseUrl}/users/login');
    // Comparar el cuerpo sin exponer la contraseña en un fallo.
    expect(
      jsonEncode(api.body) ==
          jsonEncode({'email': 'ana@example.com', 'password': 'dummy-input'}),
      isTrue,
    );
    expect(api.withAuth, isFalse);
    expect(api.hasToken, isTrue);
    expect(vm.isAuthenticated, isTrue);
    expect(vm.isLoading, isFalse);
    expect(vm.error, isNull);
    final user = vm.usuario!;
    expect(user.idUsuario, 42);
    expect(user.nombres, _user['names']);
    expect(user.apellidos, _user['surnames']);
    expect(user.nombre, 'Ana Maria Perez Ruiz');
    expect(user.codigo, '0012345');
    expect(user.correo, _user['email']);
    expect(user.escuela, _user['school']);
    expect(user.ciclo, 9);
    expect(user.createdAt, _user['createdAt']);
    expect(UsuarioModel.fromEntity(user).toJson(), _user);
    vm.dispose();
  });

  for (final field in _user.keys) {
    test('rechaza usuario sin $field y no conserva sesión anterior', () async {
      final api = _FakeApi();
      final vm = _vm(api);
      await vm.login('ana@example.com', 'dummy-input');
      api.response['user'] = Map<String, dynamic>.from(_user)..remove(field);
      expect(await vm.login('ana@example.com', 'dummy-input'), isFalse);
      expect(api.hasToken, isFalse);
      expect(vm.token == null, isTrue);
      expect(vm.usuario, isNull);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.isLoading, isFalse);
      expect(vm.error, contains('inesperada'));
      vm.dispose();
    });
  }

  final invalidResponses = <Map<String, dynamic>>[
    {},
    {'token': 'legacy', 'usuario': _user},
    {'accessToken': '', 'user': _user},
    {'accessToken': 7, 'user': _user},
    {'accessToken': 'test-session', 'user': []},
    {
      'accessToken': 'test-session',
      'user': {..._user, 'id': '42'},
    },
    {
      'accessToken': 'test-session',
      'user': {..._user, 'cycle': 13},
    },
    {
      'accessToken': 'test-session',
      'user': {..._user, 'createdAt': 'invalid'},
    },
    {
      'accessToken': 'test-session',
      'user': {..._user, 'names': ''},
    },
  ];
  for (var i = 0; i < invalidResponses.length; i++) {
    test('respuesta inesperada $i no autentica', () async {
      final api = _FakeApi()..response = invalidResponses[i];
      final vm = _vm(api);
      expect(await vm.login('ana@example.com', 'dummy-input'), isFalse);
      expect(api.hasToken, isFalse);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.error, contains('inesperada'));
      vm.dispose();
    });
  }

  final errors = <(Object, String)>[
    (ApiException(statusCode: 401, mensaje: 'backend'), 'incorrectos'),
    (ApiException(statusCode: 400, mensaje: 'backend'), 'Verifica'),
    (ApiException(statusCode: 500, mensaje: 'backend'), 'Inténtalo'),
    (TimeoutException('test'), 'tardó'),
    (http.ClientException('test'), 'conectar'),
    (const FormatException('test'), 'inesperada'),
  ];
  for (var i = 0; i < errors.length; i++) {
    test('error $i es comprensible y permite reintentar', () async {
      final api = _FakeApi();
      final vm = _vm(api);
      await vm.login('ana@example.com', 'dummy-input');
      api.failure = errors[i].$1;
      expect(await vm.login('ana@example.com', 'dummy-input'), isFalse);
      expect(vm.error, contains(errors[i].$2));
      expect(vm.isLoading, isFalse);
      expect(vm.usuario, isNull);
      expect(vm.token == null, isTrue);
      expect(api.hasToken, isFalse);
      api.failure = null;
      expect(await vm.login('ana@example.com', 'dummy-input'), isTrue);
      await vm.logout();
      expect(vm.isAuthenticated, isFalse);
      expect(vm.usuario, isNull);
      expect(api.hasToken, isFalse);
      vm.dispose();
    });
  }

  test('evita solicitudes simultáneas de login', () async {
    final api = _FakeApi()..wait = Completer<void>();
    final vm = _vm(api);
    final pending = vm.login('ana@example.com', 'dummy-input');
    expect(vm.isLoading, isTrue);
    expect(await vm.login('ana@example.com', 'dummy-input'), isFalse);
    expect(api.calls, 1);
    api.wait!.complete();
    expect(await pending, isTrue);
    vm.dispose();
  });

  testWidgets('login válido navega únicamente al Home', (tester) async {
    final api = _FakeApi();
    final vm = _vm(api);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: MaterialApp(
          home: const LoginScreen(),
          routes: {
            '/home': (_) => const Scaffold(body: Text('Home de prueba')),
          },
        ),
      ),
    );
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'dummy-input');
    await tester.ensureVisible(find.byType(ElevatedButton));
    await tester.tap(find.byType(ElevatedButton));
    await tester.pumpAndSettle();
    expect(find.text('Home de prueba'), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });
}

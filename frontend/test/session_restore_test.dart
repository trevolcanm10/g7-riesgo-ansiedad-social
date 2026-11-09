import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/session_gate.dart';
import 'package:ansiedad_ml_app/presentation/pages/auth/login_screen.dart';
import 'package:ansiedad_ml_app/core/constants.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/services/session_store.dart';
import 'package:ansiedad_ml_app/domain/usecases/login_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/logout_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';
import 'package:ansiedad_ml_app/domain/usecases/restaurar_sesion_usecase.dart';
import 'package:ansiedad_ml_app/presentation/viewmodels/auth_viewmodel.dart';
import 'fake_session_store.dart';

const user = {
  'id': 1,
  'names': 'Ana',
  'surnames': 'Perez',
  'code': '001',
  'email': 'ana@example.com',
  'school': 'Sistemas',
  'cycle': 9,
  'createdAt': '2026-10-11T00:00:00Z',
};

class SessionApi extends ApiService {
  Object? error;
  bool active = false;
  int gets = 0;
  final started = Completer<void>();
  Completer<Map<String, dynamic>>? pending;
  @override
  void setToken(String? token) {
    active = token != null;
    super.setToken(token);
  }

  @override
  Future<Map<String, dynamic>> getWithToken(String url, String token) async {
    gets++;
    expect(url, AppConstants.usersMe);
    expect(token == 'stored-test', isTrue);
    if (!started.isCompleted) started.complete();
    if (pending != null) return pending!.future;
    if (error != null) throw error!;
    return user;
  }

  @override
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    int? expectedStatus,
  }) async => {
    'accessToken': 'new-test',
    'user': {...user, 'id': 2},
  };
}

class BlockingSessionStore extends FakeSessionStore {
  final started = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(StoredSession value) async {
    started.complete();
    await release.future;
    await super.write(value);
  }
}

AuthViewModel createVm(SessionApi api, FakeSessionStore store) {
  final repo = AuthRepositoryImpl(AuthRemoteDataSource(api), store);
  return AuthViewModel(
    LoginUseCase(repo),
    RegisterUseCase(repo),
    LogoutUseCase(repo),
    RestaurarSesionUseCase(repo),
  );
}

FakeSessionStore saved() =>
    FakeSessionStore()
      ..session = StoredSession('stored-test', AppConstants.usersOrigin);

void main() {
  test(
    'no publica autenticación antes de completar escritura segura',
    () async {
      final api = SessionApi();
      final store = BlockingSessionStore();
      final vm = createVm(api, store);
      final login = vm.login('ana@example.com', 'dummy');
      await store.started.future;
      expect(vm.isAuthenticated, isFalse);
      expect(api.active, isFalse);
      store.release.complete();
      expect(await login, isTrue);
      expect(vm.isAuthenticated, isTrue);
      vm.dispose();
    },
  );

  test(
    'logout durante escritura pendiente termina sin sesión persistida',
    () async {
      final api = SessionApi();
      final store = BlockingSessionStore();
      final vm = createVm(api, store);
      final login = vm.login('ana@example.com', 'dummy');
      await store.started.future;
      final logout = vm.logout();
      store.release.complete();
      expect(await login, isFalse);
      expect(await logout, isTrue);
      expect(store.session == null, isTrue);
      expect(api.active, isFalse);
      expect(vm.isAuthenticated, isFalse);
      vm.dispose();
    },
  );

  testWidgets('ruta protegida deja de mostrar contenido después de logout', (
    tester,
  ) async {
    final vm = createVm(SessionApi(), FakeSessionStore());
    await vm.login('ana@example.com', 'dummy');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: vm,
        child: const MaterialApp(
          home: SessionProtected(child: Text('Contenido protegido')),
        ),
      ),
    );
    expect(find.text('Contenido protegido'), findsOneWidget);
    await vm.logout();
    await tester.pumpAndSettle();
    expect(find.text('Contenido protegido'), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    vm.dispose();
  });
  test('restauración HTTP envía Bearer al endpoint Users real', () async {
    final store = saved();
    final repo = AuthRepositoryImpl(AuthRemoteDataSource(ApiService()), store);
    await http.runWithClient(
      () async {
        final result = await repo.restaurarSesion();
        expect(result?.usuario.idUsuario, 1);
      },
      () => MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), AppConstants.usersMe);
        expect(
          request.headers['Authorization'] == 'Bearer stored-test',
          isTrue,
        );
        return http.Response(jsonEncode(user), 200);
      }),
    );
  });
  test('arranque sin sesión no consulta backend', () async {
    final api = SessionApi();
    final vm = createVm(api, FakeSessionStore());
    await vm.restaurarSesion();
    expect(vm.sessionChecked, isTrue);
    expect(vm.isAuthenticated, isFalse);
    expect(api.gets, 0);
    vm.dispose();
  });
  test('restaura usuario válido y publica token', () async {
    final api = SessionApi();
    final vm = createVm(api, saved());
    await vm.restaurarSesion();
    expect(vm.isAuthenticated, isTrue);
    expect(vm.idUsuario, 1);
    expect(api.active, isTrue);
    vm.dispose();
  });
  for (final code in [401, 404]) {
    test('HTTP $code elimina sesión', () async {
      final api = SessionApi()
        ..error = ApiException(statusCode: code, mensaje: 'test');
      final store = saved();
      final vm = createVm(api, store);
      await vm.restaurarSesion();
      expect(store.session == null, isTrue);
      expect(vm.isAuthenticated, isFalse);
      expect(vm.restoreError, isNull);
      vm.dispose();
    });
  }
  for (final failure in [
    http.ClientException('test'),
    TimeoutException('test'),
    ApiException(statusCode: 503, mensaje: 'test'),
  ]) {
    test(
      'fallo transitorio conserva sesión y admite reintento ${failure.runtimeType}',
      () async {
        final api = SessionApi()..error = failure;
        final store = saved();
        final vm = createVm(api, store);
        await vm.restaurarSesion();
        expect(store.session != null, isTrue);
        expect(vm.restoreError, isNotNull);
        api.error = null;
        await vm.restaurarSesion();
        expect(vm.isAuthenticated, isTrue);
        vm.dispose();
      },
    );
  }
  test('otro origen nunca recibe token', () async {
    final api = SessionApi();
    final store = saved()
      ..session = const StoredSession('stored-test', 'http://other');
    final vm = createVm(api, store);
    await vm.restaurarSesion();
    expect(api.gets, 0);
    expect(store.session == null, isTrue);
    vm.dispose();
  });
  test('fallo de escritura no autentica', () async {
    final api = SessionApi();
    final store = FakeSessionStore()..failWrite = true;
    final vm = createVm(api, store);
    expect(await vm.login('ana@example.com', 'dummy'), isFalse);
    expect(vm.isAuthenticated, isFalse);
    expect(api.active, isFalse);
    expect(vm.error, contains('guardar'));
    vm.dispose();
  });
  test(
    'fallo de borrado bloquea restauración y permite reintentar logout',
    () async {
      final api = SessionApi();
      final store = saved();
      final vm = createVm(api, store);
      await vm.restaurarSesion();
      store.failDelete = true;
      expect(await vm.logout(), isFalse);
      expect(vm.isAuthenticated, isFalse);
      expect(api.active, isFalse);
      expect(vm.logoutFailed, isTrue);
      await vm.restaurarSesion();
      expect(api.gets, 1);
      store.failDelete = false;
      expect(await vm.logout(), isTrue);
      expect(store.session == null, isTrue);
      vm.dispose();
    },
  );
  test('logout durante restauración pendiente no revive sesión', () async {
    final api = SessionApi()..pending = Completer();
    final store = saved();
    final vm = createVm(api, store);
    final restoring = vm.restaurarSesion();
    await api.started.future;
    await vm.logout();
    api.pending!.complete(user);
    await restoring;
    expect(vm.isAuthenticated, isFalse);
    expect(api.active, isFalse);
    expect(store.session == null, isTrue);
    vm.dispose();
  });
  test('restauración antigua no reemplaza login posterior', () async {
    final api = SessionApi()..pending = Completer();
    final store = saved();
    final vm = createVm(api, store);
    final restoring = vm.restaurarSesion();
    await api.started.future;
    expect(await vm.login('ana@example.com', 'dummy'), isTrue);
    api.pending!.complete(user);
    await restoring;
    expect(vm.idUsuario, 2);
    expect(api.active, isTrue);
    expect(store.session?.token == 'new-test', isTrue);
    vm.dispose();
  });
}

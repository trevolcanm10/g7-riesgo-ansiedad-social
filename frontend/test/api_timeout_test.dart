import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/core/constants.dart';

Future<void> register(AuthRemoteDataSource source) => source.registrar(
  nombres: 'Prueba',
  apellidos: 'Local',
  codigo: '001',
  correo: 'test@example.com',
  contrasena: 'fixture-only',
  escuela: 'Sistemas',
  ciclo: 9,
);

void main() {
  test('timeout configurable de 60 segundos por defecto y limites validos', () {
    const configured = int.fromEnvironment(
      'HTTP_TIMEOUT_SECONDS',
      defaultValue: 60,
    );
    expect(ApiService().requestTimeout, Duration(seconds: configured));
    expect(
      ApiService(requestTimeout: const Duration(seconds: 30)).requestTimeout,
      const Duration(seconds: 30),
    );
    for (final timeout in [
      Duration.zero,
      const Duration(seconds: -1),
      const Duration(seconds: 181),
    ]) {
      expect(() => ApiService(requestTimeout: timeout), throwsArgumentError);
    }
  });

  testWidgets('registro simulado de 24.84 segundos completa sin reintentos', (
    tester,
  ) async {
    var calls = 0;
    late http.Request captured;
    final pending = Completer<http.Response>();
    await http.runWithClient(
      () async {
        var completed = false;
        final operation = register(
          AuthRemoteDataSource(ApiService()),
        ).then((_) => completed = true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 24840));
        expect(completed, isFalse);
        pending.complete(http.Response('{}', 201));
        await tester.pump();
        await operation;
        expect(completed, isTrue);
        expect(calls, 1);
        expect(captured.method, 'POST');
        expect(captured.url.toString(), AppConstants.registroUsers);
        expect(captured.headers['Content-Type'], 'application/json');
        expect(captured.headers.containsKey('Authorization'), isFalse);
        if (AppConstants.gateway.enabled) {
          expect(
            captured.headers.containsKey('Ocp-Apim-Subscription-Key'),
            isTrue,
          );
        }
        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body.keys.toSet(), {
          'names',
          'surnames',
          'code',
          'email',
          'password',
          'school',
          'cycle',
        });
        expect(body['code'], '001');
        expect(body['cycle'], isA<int>());
        expect(body['cycle'], 9);
      },
      () => MockClient((request) {
        calls++;
        captured = request;
        return pending.future;
      }),
    );
  });

  final methods = <String, Future<dynamic> Function(ApiService)>{
    'GET': (api) => api.get('http://local/test'),
    'LIST': (api) => api.getList('http://local/test'),
    'POST': (api) => api.post('http://local/test', withAuth: false),
    'PUT': (api) => api.put('http://local/test'),
    'DELETE': (api) => api.delete('http://local/test'),
    'RESTORE': (api) => api.getWithToken('http://local/test', 'fixture'),
  };
  for (final method in methods.entries) {
    testWidgets(
      '${method.key} utiliza el timeout configurado sin retry automatico',
      (tester) async {
        final pending = Completer<http.Response>();
        var calls = 0;
        await http.runWithClient(
          () async {
            final api = ApiService(requestTimeout: const Duration(seconds: 30));
            final operation = method.value(api);
            final expectation = expectLater(
              operation,
              throwsA(isA<TimeoutException>()),
            );
            await tester.pump();
            await tester.pump(const Duration(seconds: 31));
            await expectation;
            expect(calls, 1);
            pending.complete(http.Response('{}', 200));
            await tester.pump();
          },
          () => MockClient((_) {
            calls++;
            return pending.future;
          }),
        );
      },
    );
  }

  testWidgets('registro conserva error comprensible tras timeout', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    await http.runWithClient(() async {
      final operation = register(
        AuthRemoteDataSource(
          ApiService(requestTimeout: const Duration(seconds: 1)),
        ),
      );
      final expectation = expectLater(
        operation,
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('tardó en responder'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      await expectation;
      pending.complete(http.Response('{}', 201));
      await tester.pump();
    }, () => MockClient((_) => pending.future));
  });
}

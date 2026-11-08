import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ansiedad_ml_app/core/api_gateway_config.dart';
import 'package:ansiedad_ml_app/core/constants.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';

const gateway = ApiGatewayConfig(
  baseUrl: 'https://apim-g7-riesgo-ansiedad.azure-api.net/',
  subscriptionKey: 'fake-subscription',
);

void main() {
  test('rutas Azure exactas y normalizacion de barra final', () {
    expect(gateway.registration, '${gateway.origin}/u/users');
    expect(gateway.login, '${gateway.origin}/u/users/login');
    expect(gateway.evaluation, '${gateway.origin}/re/risk-evaluations');
    expect(gateway.usersOrigin, '${gateway.origin}/u');
  });

  test('dart-define selecciona rutas APIM o rutas locales independientes', () {
    const apim = String.fromEnvironment('APIM_BASE_URL');
    const users = String.fromEnvironment('USERS_BASE_URL');
    const risk = String.fromEnvironment('RISK_EVALUATION_BASE_URL');
    if (apim.isNotEmpty) {
      final origin = apim.replaceAll(RegExp(r'/+$'), '');
      expect(AppConstants.registroUsers, '$origin/u/users');
      expect(AppConstants.login, '$origin/u/users/login');
      expect(AppConstants.usersMe, '$origin/u/users/me');
      expect(AppConstants.evaluar, '$origin/re/risk-evaluations');
    } else {
      final usersOrigin = users.isEmpty ? AppConstants.baseUrl : users;
      expect(AppConstants.registroUsers, '$usersOrigin/users');
      expect(AppConstants.login, '$usersOrigin/users/login');
      expect(
        AppConstants.evaluar,
        '${risk.isEmpty ? 'http://localhost:3002' : risk}/risk-evaluations/',
      );
    }
  });

  test('clave no se envia a localhost, otros hosts o prefijos ajenos', () {
    for (final url in [
      'http://localhost:5000/users',
      'https://other.example/u/users',
      'http://${Uri.parse(gateway.origin).host}/u/users',
    ]) {
      expect(gateway.headersFor(url), isEmpty);
    }
    const prefix = ApiGatewayConfig(
      baseUrl: 'https://example.test/gateway',
      subscriptionKey: 'fake',
    );
    expect(
      prefix.headersFor('https://example.test/gateway-other/u/users'),
      isEmpty,
    );
    expect(
      prefix.headersFor('https://example.test/gateway/u/users'),
      isNotEmpty,
    );
    expect(
      const ApiGatewayConfig(subscriptionKey: 'fake').headersFor(gateway.login),
      isEmpty,
    );
  });

  test(
    'configuracion incompleta o insegura se rechaza antes de enviar',
    () async {
      for (final config in const [
        ApiGatewayConfig(baseUrl: 'https://gateway.example'),
        ApiGatewayConfig(
          baseUrl: 'http://gateway.example',
          subscriptionKey: 'fake',
        ),
      ]) {
        var calls = 0;
        await http.runWithClient(
          () async {
            await expectLater(
              ApiService(
                gateway: config,
              ).post('${config.origin}/u/users', withAuth: false),
              throwsFormatException,
            );
          },
          () => MockClient((_) async {
            calls++;
            return http.Response('{}', 200);
          }),
        );
        expect(calls, 0);
      }
    },
  );

  test(
    'login y registro llevan suscripcion sin Bearer; evaluacion lleva ambos',
    () async {
      final api = ApiService(gateway: gateway)..setToken('fake-jwt');
      final requests = <http.Request>[];
      await http.runWithClient(
        () async {
          await api.post(
            gateway.registration,
            withAuth: false,
            body: {'cycle': 9},
          );
          await api.post(
            gateway.login,
            withAuth: false,
            body: {'email': 'test@example.com'},
          );
          await api.post(
            gateway.evaluation,
            expectedStatus: 201,
            body: {'phq9Score': 27, 'gad7Score': 14, 'gpa': 2.5},
          );
        },
        () => MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{}',
            request.url.path.startsWith('/re/') ? 201 : 200,
          );
        }),
      );
      for (final request in requests) {
        expect(
          request.headers['Ocp-Apim-Subscription-Key'],
          'fake-subscription',
        );
        expect(request.headers['Content-Type'], 'application/json');
      }
      expect(requests[0].headers.containsKey('Authorization'), isFalse);
      expect(requests[1].headers.containsKey('Authorization'), isFalse);
      expect(requests[2].headers['Authorization'], 'Bearer fake-jwt');
      final body = jsonDecode(requests[2].body) as Map<String, dynamic>;
      expect(body['phq9Score'], isA<int>());
      expect(body['gpa'], 2.5);
      expect(body.containsKey('token'), isFalse);
    },
  );

  test('todos los metodos y restauracion incluyen suscripcion', () async {
    final api = ApiService(gateway: gateway)..setToken('active-fixture');
    var calls = 0;
    await http.runWithClient(
      () async {
        final url = '${gateway.usersOrigin}/users/me';
        await api.get(url);
        await api.getList('$url/list');
        await api.put(url);
        await api.delete(url);
        await api.getWithToken(url, 'candidate-fixture');
      },
      () => MockClient((request) async {
        calls++;
        expect(
          request.headers['Ocp-Apim-Subscription-Key'],
          'fake-subscription',
        );
        expect(
          request.headers['Authorization'],
          calls == 5 ? 'Bearer candidate-fixture' : 'Bearer active-fixture',
        );
        return http.Response(
          request.url.path.endsWith('/list') ? '[]' : '{}',
          200,
        );
      }),
    );
    expect(calls, 5);
  });

  test(
    '401 publico no invalida; 401 protegido conserva invalidacion global',
    () async {
      final api = ApiService(gateway: gateway)..setToken('fake-jwt');
      var invalidations = 0;
      api.onUnauthorized = () async {
        invalidations++;
      };
      await http.runWithClient(
        () async {
          await expectLater(
            api.post(gateway.login, withAuth: false),
            throwsA(isA<ApiException>()),
          );
          expect(invalidations, 0);
          await expectLater(
            api.post(gateway.evaluation),
            throwsA(isA<ApiException>()),
          );
          expect(invalidations, 1);
        },
        () => MockClient(
          (_) async => http.Response('{"message":"Unauthorized"}', 401),
        ),
      );
    },
  );

  test('500 captura request-id de APIM y toString lo referencia', () async {
    final api = ApiService(gateway: gateway);
    await http.runWithClient(
      () async {
        await expectLater(
          api.post(gateway.evaluation, expectedStatus: 201),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.apimRequestId, 'apimRequestId',
                    'test-req-500')
                .having((e) => e.apimTraceLocation, 'apimTraceLocation',
                    'https://trace/500'),
          ),
        );
      },
      () => MockClient((_) async => http.Response(
            '{"message":"Error interno del servidor"}',
            500,
            headers: {
              'ocp-apim-request-id': 'test-req-500',
              'ocp-apim-trace-location': 'https://trace/500',
            },
          )),
    );
  });

  test('registro con 500 expone referencia APIM sin filtrar credenciales',
      () async {
    final api = ApiService(gateway: gateway);
    final ds = AuthRemoteDataSource(api);
    await http.runWithClient(
      () async {
        await expectLater(
          ds.registrar(
            nombres: 'Ana',
            apellidos: 'Perez',
            codigo: 'C001',
            correo: 'ana@example.com',
            contrasena: 'pw-secreto',
            escuela: 'Ingenieria',
            ciclo: 3,
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'mensaje',
              allOf(
                contains('no está disponible'),
                contains('ref. APIM test-req-500'),
              ),
            ),
          ),
        );
      },
      () => MockClient((_) async => http.Response(
            '{"message":"Error interno del servidor"}',
            500,
            headers: {'ocp-apim-request-id': 'test-req-500'},
          )),
    );
  });

}

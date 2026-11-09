import 'fake_session_store.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ansiedad_ml_app/data/datasources/remote/api_service.dart';
import 'package:ansiedad_ml_app/data/datasources/remote/auth_remote_datasource.dart';
import 'package:ansiedad_ml_app/data/repositories/auth_repository_impl.dart';
import 'package:ansiedad_ml_app/domain/usecases/register_usecase.dart';

/// ApiService falso que captura la petición sin realizar HTTP.
class _ApiServicePrueba extends ApiService {
  String? urlCapturada;
  Map<String, dynamic>? bodyCapturado;
  bool? withAuthCapturado;
  Object? errorAInsertar;

  @override
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    int? expectedStatus,
  }) async {
    urlCapturada = url;
    bodyCapturado = body;
    withAuthCapturado = withAuth;
    final error = errorAInsertar;
    if (error != null) throw error;
    return {'id': 42};
  }
}

/// Construye el UseCase de registro sobre el ApiService falso.
RegisterUseCase _crearUseCase(_ApiServicePrueba api) {
  return RegisterUseCase(
    AuthRepositoryImpl(AuthRemoteDataSource(api), FakeSessionStore()),
  );
}

/// Dispara el registro con los datos de muestra del contrato Users.
Future<void> _registrarMuestra(RegisterUseCase useCase) {
  return useCase(
    nombres: 'Juan',
    apellidos: 'Pérez',
    codigo: '0012345',
    correo: 'juan@example.com',
    contrasena: 'Ejemplo123!',
    escuela: 'Ingeniería de Software',
    ciclo: 9,
  );
}

void main() {
  test('envía exactamente los siete campos del contrato Users', () async {
    final api = _ApiServicePrueba();
    await _registrarMuestra(_crearUseCase(api));

    expect(api.bodyCapturado, isNotNull);
    expect(api.bodyCapturado!.length, 7);
    expect(api.bodyCapturado!.keys.toSet(), <String>{
      'names',
      'surnames',
      'code',
      'email',
      'password',
      'school',
      'cycle',
    });
    expect(api.bodyCapturado!['names'], 'Juan');
    expect(api.bodyCapturado!['surnames'], 'Pérez');
    expect(api.bodyCapturado!['email'], 'juan@example.com');
    expect(api.bodyCapturado!['password'], 'Ejemplo123!');
    expect(api.bodyCapturado!['school'], 'Ingeniería de Software');

    // POST /users sin autenticación (aún no hay JWT de Users).
    expect(api.urlCapturada, endsWith('/users'));
    expect(api.withAuthCapturado, isFalse);
  });

  test('cycle se envía como número entero', () async {
    final api = _ApiServicePrueba();
    await _registrarMuestra(_crearUseCase(api));

    expect(api.bodyCapturado!['cycle'], isA<int>());
    expect(api.bodyCapturado!['cycle'], 9);
  });

  test('code se envía como texto conservando los ceros iniciales', () async {
    final api = _ApiServicePrueba();
    await _registrarMuestra(_crearUseCase(api));

    expect(api.bodyCapturado!['code'], isA<String>());
    expect(api.bodyCapturado!['code'], '0012345');
  });

  test('no envía campos adicionales (id, createdAt, confirmation)', () async {
    final api = _ApiServicePrueba();
    await _registrarMuestra(_crearUseCase(api));

    final body = api.bodyCapturado!;
    expect(body.containsKey('id'), isFalse);
    expect(body.containsKey('createdAt'), isFalse);
    expect(body.containsKey('confirmation'), isFalse);
    expect(body.length, 7);
  });

  test('HTTP 400 conserva los errores por campo del backend', () async {
    final api = _ApiServicePrueba();
    api.errorAInsertar = ApiException(
      statusCode: 400,
      mensaje: 'Error desconocido',
      cuerpo:
          '{"errors": [{"field": "email", "message": "Email inválido"}, '
          '{"field": "code", "message": "Código inválido"}]}',
    );

    await expectLater(
      _registrarMuestra(_crearUseCase(api)),
      throwsA(
        isA<Exception>()
            .having((e) => e.toString(), 'mensaje', contains('Email inválido'))
            .having(
              (e) => e.toString(),
              'mensaje',
              contains('Código inválido'),
            ),
      ),
    );
  });

  test('HTTP 409 conserva el mensaje específico del backend', () async {
    final api = _ApiServicePrueba();
    api.errorAInsertar = ApiException(
      statusCode: 409,
      mensaje: 'El email ya está registrado',
    );

    await expectLater(
      _registrarMuestra(_crearUseCase(api)),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('El email ya está registrado'),
        ),
      ),
    );
  });

  test('HTTP 409 sin mensaje útil usa el mensaje por defecto', () async {
    final api = _ApiServicePrueba();
    api.errorAInsertar = ApiException(
      statusCode: 409,
      mensaje: 'Error desconocido',
    );

    await expectLater(
      _registrarMuestra(_crearUseCase(api)),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('ya está registrado'),
        ),
      ),
    );
  });

  test('diferencia errores de conexión de excepciones inesperadas', () async {
    final apiConTimeout = _ApiServicePrueba()
      ..errorAInsertar = TimeoutException('tiempo agotado');
    await expectLater(
      _registrarMuestra(_crearUseCase(apiConTimeout)),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('tardó en responder'),
        ),
      ),
    );

    final apiSinRed = _ApiServicePrueba()
      ..errorAInsertar = http.ClientException('sin conexión');
    await expectLater(
      _registrarMuestra(_crearUseCase(apiSinRed)),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'mensaje',
          contains('No se pudo conectar'),
        ),
      ),
    );

    // Una excepción inesperada de programación NO se oculta como error de red.
    final apiRara = _ApiServicePrueba()
      ..errorAInsertar = StateError('fallo de programación');
    await expectLater(
      _registrarMuestra(_crearUseCase(apiRara)),
      throwsA(isA<StateError>()),
    );
  });
}

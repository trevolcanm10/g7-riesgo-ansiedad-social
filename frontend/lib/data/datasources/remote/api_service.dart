import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../core/constants.dart';
import '../../../../core/api_gateway_config.dart';

/// Servicio genérico para realizar llamadas HTTP al backend.
///
/// Esta clase reside en la capa de datos porque es un detalle
/// de implementación de la comunicación con la API.
class ApiService {
  final ApiGatewayConfig _gateway;

  /// One request budget, including response body. No automatic POST retries.
  /// 60 s leaves margin above the observed 24.84 s remote registration.
  static const defaultTimeoutSeconds = int.fromEnvironment(
    'HTTP_TIMEOUT_SECONDS',
    defaultValue: 60,
  );
  final Duration requestTimeout;
  ApiService({ApiGatewayConfig? gateway, Duration? requestTimeout})
    : _gateway = gateway ?? AppConstants.gateway,
      requestTimeout =
          requestTimeout ?? const Duration(seconds: defaultTimeoutSeconds) {
    if (this.requestTimeout <= Duration.zero ||
        this.requestTimeout > const Duration(minutes: 3)) {
      throw ArgumentError(
        'HTTP timeout must be greater than zero and at most 180 seconds.',
      );
    }
  }
  Future<void> Function()? onUnauthorized;
  int _sessionVersion = 0;

  Future<void> _checkUnauthorized(
    http.Response response,
    (String?, int) session,
  ) async {
    if (response.statusCode != 401 ||
        session.$1 == null ||
        session.$1 != _token ||
        session.$2 != _sessionVersion) {
      return;
    }
    // Invalidate synchronously before notifying: concurrent responses become stale.
    setToken(null);
    await onUnauthorized?.call();
  }

  /// Candidate session verification never changes the shared active token.
  Future<Map<String, dynamic>> getWithToken(String url, String token) async {
    final response = await http
        .get(Uri.parse(url), headers: _headers(url, candidateToken: token))
        .timeout(requestTimeout);
    return _procesarRespuesta(response);
  }

  String? _token;

  /// Establece el token JWT para autenticación
  void setToken(String? token) {
    _token = token;
    _sessionVersion++;
  }

  /// Construye los headers con autenticación si hay token
  Map<String, String> _headers(
    String url, {
    bool withAuth = true,
    String? candidateToken,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ..._gateway.headersFor(url),
    };
    final token = candidateToken ?? _token;
    if (withAuth && token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Realiza una petición GET
  Future<Map<String, dynamic>> get(String url) async {
    final session = (_token, _sessionVersion);
    final response = await http
        .get(Uri.parse(url), headers: _headers(url))
        .timeout(requestTimeout);
    await _checkUnauthorized(response, session);
    return _procesarRespuesta(response);
  }

  /// Realiza una petición GET que devuelve una lista
  Future<List<dynamic>> getList(String url) async {
    final session = (_token, _sessionVersion);
    final response = await http
        .get(Uri.parse(url), headers: _headers(url))
        .timeout(requestTimeout);
    await _checkUnauthorized(response, session);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw ApiException(
      statusCode: response.statusCode,
      mensaje: _extraerMensaje(response.body),
    );
  }

  /// Realiza una petición POST
  Future<Map<String, dynamic>> post(
    String url, {
    Map<String, dynamic>? body,
    bool withAuth = true,
    int? expectedStatus,
  }) async {
    final session = (withAuth ? _token : null, _sessionVersion);
    final response = await http
        .post(
          Uri.parse(url),
          headers: _headers(url, withAuth: withAuth),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(requestTimeout);
    await _checkUnauthorized(response, session);
    if (expectedStatus != null &&
        response.statusCode >= 200 &&
        response.statusCode < 300 &&
        response.statusCode != expectedStatus) {
      throw const FormatException('Código de respuesta inesperado.');
    }
    return _procesarRespuesta(response);
  }

  /// Realiza una petición PUT
  Future<Map<String, dynamic>> put(
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final session = (_token, _sessionVersion);
    final response = await http
        .put(
          Uri.parse(url),
          headers: _headers(url),
          body: body != null ? jsonEncode(body) : null,
        )
        .timeout(requestTimeout);
    await _checkUnauthorized(response, session);
    return _procesarRespuesta(response);
  }

  /// Realiza una petición DELETE
  Future<Map<String, dynamic>> delete(String url) async {
    final session = (_token, _sessionVersion);
    final response = await http
        .delete(Uri.parse(url), headers: _headers(url))
        .timeout(requestTimeout);
    await _checkUnauthorized(response, session);
    return _procesarRespuesta(response);
  }

  /// Procesa la respuesta HTTP y lanza excepción si hay error
  Map<String, dynamic> _procesarRespuesta(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'data': decoded};
    }
    throw ApiException(
      statusCode: response.statusCode,
      mensaje: _extraerMensaje(response.body),
      cuerpo: response.body,
      apimRequestId:
          response.headers['ocp-apim-request-id'] ??
          response.headers['x-ms-request-id'],
      apimTraceLocation: response.headers['ocp-apim-trace-location'],
    );
  }

  /// Extrae el mensaje de error del cuerpo de la respuesta
  String _extraerMensaje(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['mensaje'] ??
            decoded['message'] ??
            decoded['error'] ??
            'Error desconocido';
      }
    } catch (_) {}
    return 'Error en la comunicación con el servidor';
  }
}

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final int statusCode;
  final String mensaje;

  /// Cuerpo crudo de la respuesta HTTP (opcional, para errores).
  final String? cuerpo;

  /// Identificador de peticion de Azure API Management si el gateway lo
  /// incluyo en la respuesta. Sirve para correlacionar el fallo con los
  /// registros de APIM. No es una credencial.
  final String? apimRequestId;

  /// Ubicacion de la traza de APIM si esta disponible. No es una credencial.
  final String? apimTraceLocation;

  ApiException({
    required this.statusCode,
    required this.mensaje,
    this.cuerpo,
    this.apimRequestId,
    this.apimTraceLocation,
  });

  @override
  String toString() => apimRequestId == null
      ? 'ApiException($statusCode): $mensaje'
      : 'ApiException($statusCode): $mensaje [APIM $apimRequestId]';
}

import '../../../../core/constants.dart';
import '../../models/usuario_model.dart';
import 'api_service.dart';
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// DataSource remoto para operaciones de autenticación.
///
/// Esta clase encapsula todas las llamadas HTTP relacionadas con
/// autenticación, convirtiendo JSON a DTOs y viceversa.
class AuthRemoteDataSource {
  final ApiService _apiService;

  AuthRemoteDataSource(this._apiService);
  void setSessionToken(String? token) => _apiService.setToken(token);
  Future<UsuarioModel> getMe(String token, {String? url}) async =>
      UsuarioModel.fromJson(
        await _apiService.getWithToken(url ?? AppConstants.usersMe, token),
      );

  /// Inicia sesión y retorna el token y el usuario.
  Future<({String token, UsuarioModel usuario})> login({
    required String correo,
    required String contrasena,
    String? url,
  }) async {
    _apiService.setToken(null);
    try {
      final response = await _apiService.post(
        url ?? AppConstants.login,
        body: {'email': correo.trim(), 'password': contrasena},
        withAuth: false,
      );
      final token = response['accessToken'];
      final usuarioJson = response['user'];
      if (token is! String ||
          token.trim().isEmpty ||
          usuarioJson is! Map<String, dynamic>) {
        throw const FormatException('Contrato de login inválido');
      }
      final usuario = UsuarioModel.fromJson(usuarioJson);
      // El repositorio publica el token después de confirmar la escritura segura.
      return (token: token, usuario: usuario);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw Exception('Correo o contraseña incorrectos.');
      }
      if (e.statusCode == 400) {
        throw Exception('Verifica el correo y la contraseña ingresados.');
      }
      throw Exception('No se pudo iniciar sesión. Inténtalo de nuevo.');
    } on TimeoutException {
      throw Exception('El servidor tardó en responder. Inténtalo de nuevo.');
    } on http.ClientException {
      throw Exception(
        'No se pudo conectar con el servidor de inicio de sesión.',
      );
    } on FormatException {
      throw Exception(
        'El servidor devolvió una respuesta de inicio de sesión inesperada.',
      );
    } on TypeError {
      throw Exception(
        'El servidor devolvió una respuesta de inicio de sesión inesperada.',
      );
    }
  }

  /// Registra un nuevo usuario en el microservicio Users (POST /users).
  ///
  /// Envía los 7 campos obligatorios del contrato: names, surnames,
  /// code (texto), email, password, school (solo el nombre) y cycle
  /// (entero 1-12). No envía id, createdAt ni confirmación de contraseña.
  Future<void> registrar({
    required String nombres,
    required String apellidos,
    required String codigo,
    required String correo,
    required String contrasena,
    required String escuela,
    required int ciclo,
  }) async {
    final body = <String, dynamic>{
      'names': nombres,
      'surnames': apellidos,
      'code': codigo,
      'email': correo,
      'password': contrasena,
      'school': escuela,
      'cycle': ciclo,
    };

    try {
      await _apiService.post(
        AppConstants.registroUsers,
        body: body,
        withAuth: false,
      );
    } on ApiException catch (e) {
      // Errores HTTP: 400 (validación) y 409 (duplicado) conservan el
      // mensaje del backend cuando aporta información real.
      if (e.statusCode == 400) {
        throw Exception(_mensajeValidacion(e));
      }
      if (e.statusCode == 409) {
        throw Exception(_mensajeDuplicado(e));
      }
      if (e.statusCode >= 500) {
        // Un 5xx puede venir del backend o de APIM. Si trajo el request-id de
        // APIM, el fallo paso por el gateway; se expone como referencia para
        // correlacionar con sus registros. El request-id no es credencial.
        final ref = e.apimRequestId;
        throw Exception(
          ref == null
              ? 'El servicio no está disponible en este momento. Inténtalo más tarde.'
              : 'El servicio no está disponible en este momento '
                    '(ref. APIM $ref). Inténtalo más tarde.',
        );
      }
      rethrow;
    } on TimeoutException {
      throw Exception('El servidor tardó en responder. Inténtalo de nuevo.');
    } on http.ClientException {
      // Errores de conexión (DNS, TCP, TLS).
      throw Exception('No se pudo conectar con el servidor de registro.');
    }
    // Las excepciones inesperadas NO se capturan: se propagan para no
    // enmascarar errores de programación como si fueran fallos de red.
  }

  /// Mensaje para errores HTTP 400: prioriza los errores por campo.
  String _mensajeValidacion(ApiException e) {
    final detalle =
        _extraerErroresPorCampo(e.cuerpo) ?? _mensajeUtil(e.mensaje);
    if (detalle != null) return 'Datos de registro inválidos: $detalle';
    return 'Datos de registro inválidos. Verifica los campos enviados.';
  }

  /// Mensaje para errores HTTP 409: conserva el mensaje específico del
  /// backend (p. ej. "El email ya está registrado") si existe.
  String _mensajeDuplicado(ApiException e) {
    final detalle =
        _mensajeUtil(e.mensaje) ?? _extraerErroresPorCampo(e.cuerpo);
    if (detalle != null) return detalle;
    return 'El correo o el código de estudiante ya está registrado';
  }

  /// Devuelve el mensaje del backend solo si aporta información real.
  String? _mensajeUtil(String mensaje) {
    final limpio = mensaje.trim();
    if (limpio.isEmpty) return null;
    if (limpio == 'Error desconocido') return null;
    if (limpio == 'Error en la comunicación con el servidor') return null;
    return limpio;
  }

  /// Extrae los errores por campo del cuerpo JSON, si el backend los envía
  /// como arreglo ({"errors": [...]}) o como objeto ({"errors": {...}}).
  String? _extraerErroresPorCampo(String? cuerpo) {
    if (cuerpo == null || cuerpo.isEmpty) return null;
    try {
      final decoded = jsonDecode(cuerpo);
      if (decoded is! Map<String, dynamic>) return null;
      final dynamic errores =
          decoded['errors'] ?? decoded['errores'] ?? decoded['details'];
      if (errores is List) {
        final mensajes = errores
            .map((dynamic e) {
              if (e is Map<String, dynamic>) {
                return (e['message'] ??
                        e['msg'] ??
                        e['detail'] ??
                        e['error'] ??
                        '')
                    .toString();
              }
              return e.toString();
            })
            .where((m) => m.trim().isNotEmpty)
            .toList();
        if (mensajes.isNotEmpty) return mensajes.join('; ');
      }
      if (errores is Map<String, dynamic>) {
        final mensajes = errores.entries
            .map((e) => '${e.key}: ${e.value}')
            .toList();
        if (mensajes.isNotEmpty) return mensajes.join('; ');
      }
    } catch (_) {
      // Cuerpo no JSON o estructura inesperada: se usa el mensaje genérico.
    }
    return null;
  }

  /// Cierra la sesión (limpia el token del ApiService).
  Future<void> logout() async {
    // No hay endpoint de logout en el backend, solo limpiamos el token
    _apiService.setToken(null);
  }
}

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_gateway_config.dart';

/// Configuración global de la aplicación.
///
/// Centraliza constantes, URLs de API y endpoints.
/// Reemplaza la antigua clase `ApiConfig` siguiendo el principio
/// de que la capa core no debe depender de detalles de implementación.
class AppConstants {
  static const gateway = ApiGatewayConfig(
    baseUrl: String.fromEnvironment('APIM_BASE_URL'),
    subscriptionKey: String.fromEnvironment('APIM_SUBSCRIPTION_KEY'),
  );
  // ==========================================
  // CONSTANTES
  // ==========================================
  static const String _defaultPort = '5000';
  static const String _prefsKey = 'api_base_url';

  // ==========================================
  // URL BASE DETECTADA AUTOMÁTICAMENTE
  // ==========================================
  static String _baseUrl = _detectarBaseUrl();
  static bool _inicializado = false;

  /// Inicializa la configuración cargando la URL guardada (si existe)
  static Future<void> init() async {
    if (_inicializado) return;
    final prefs = await SharedPreferences.getInstance();
    final guardada = prefs.getString(_prefsKey);
    if (guardada != null && guardada.isNotEmpty) {
      _baseUrl = guardada;
    }
    _inicializado = true;
  }

  /// Obtiene la URL base actual
  static String get baseUrl => _baseUrl;

  /// Cambia la URL base y la persiste
  static Future<void> setBaseUrl(String nuevaUrl) async {
    // Limpiar la URL: quitar barra al final si la tiene
    _baseUrl = nuevaUrl.replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _baseUrl);
  }

  /// Restablece la URL base a la detectada automáticamente
  static Future<void> resetBaseUrl() async {
    _baseUrl = _detectarBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// URL base para producción (Render)
  static const String _produccionUrl =
      'https://ansiedad-riesgo-ml-app.onrender.com';

  /// Detecta la URL base según la plataforma
  static String _detectarBaseUrl() {
    // En producción (release mode), usar URL de Render
    if (kReleaseMode) {
      return _produccionUrl;
    }

    // En desarrollo web, usar localhost
    if (kIsWeb) {
      return 'http://localhost:$_defaultPort';
    }

    try {
      if (Platform.isAndroid) {
        // En emulador Android, 10.0.2.2 apunta al host local de la máquina
        // En dispositivo físico, se necesita la IP real del servidor
        return 'http://10.0.2.2:$_defaultPort';
      } else if (Platform.isIOS) {
        // En iOS Simulator, localhost funciona directamente
        // En dispositivo físico, se necesita la IP real del servidor
        return 'http://localhost:$_defaultPort';
      } else if (Platform.isMacOS) {
        return 'http://localhost:$_defaultPort';
      } else if (Platform.isWindows) {
        return 'http://localhost:$_defaultPort';
      } else if (Platform.isLinux) {
        return 'http://localhost:$_defaultPort';
      }
    } catch (_) {
      // Si hay algún error al detectar la plataforma, usar localhost
    }

    return 'http://localhost:$_defaultPort';
  }

  // ==========================================
  // ENDPOINTS DE AUTENTICACIÓN
  // ==========================================
  static String get registro => '$_baseUrl/registro';

  /// Permite apuntar el login a Users sin cambiar la URL del registro existente.
  static const String _usersLoginBaseUrl = String.fromEnvironment(
    'USERS_BASE_URL',
  );
  static String get login {
    if (gateway.enabled) return gateway.login;
    final base = _usersLoginBaseUrl.isEmpty ? _baseUrl : _usersLoginBaseUrl;
    return '${base.replaceAll(RegExp(r'/+$'), '')}/users/login';
  }

  static String get usersOrigin =>
      login.substring(0, login.length - '/users/login'.length);
  static String get usersMe => '$usersOrigin/users/me';

  // ==========================================
  // ENDPOINT DE REGISTRO (MICROSERVICIO USERS)
  // ==========================================
  /// Registro de usuarios en el microservicio Users (POST /users).
  /// La URL base nunca termina en barra (ver [setBaseUrl]), por lo que
  /// el prefijo /users no se duplica.
  static String get registroUsers =>
      gateway.enabled ? gateway.registration : '$usersOrigin/users';

  // ==========================================
  // ENDPOINTS DE EVALUACIONES (microservicio RiskEvaluation)
  // ==========================================

  /// Puerto local del microservicio RiskEvaluation.
  static const String _riskEvaluationPort = '3002';

  /// Base URL de RiskEvaluation, independiente de la de Users.
  ///
  /// Se define en tiempo de compilacion con la bandera
  /// --dart-define=RISK_EVALUATION_BASE_URL=https://mi-servicio
  static const String _riskEvaluationBaseUrl = String.fromEnvironment(
    'RISK_EVALUATION_BASE_URL',
  );

  /// Host local de RiskEvaluation segun la plataforma.
  ///
  /// RiskEvaluation no comparte despliegue con Users, por lo que no se reutiliza
  /// [_baseUrl] (que apunta al puerto de Users); solo se toma prestado el host
  /// que corresponde al emulador de cada plataforma.
  static String? _detectarRiskEvaluationHost() {
    try {
      if (Platform.isAndroid) {
        return 'http://10.0.2.2:$_riskEvaluationPort';
      }
      if (Platform.isWindows ||
          Platform.isLinux ||
          Platform.isMacOS ||
          Platform.isIOS) {
        return 'http://localhost:$_riskEvaluationPort';
      }
    } catch (_) {
      // Plataforma sin soporte de dart:io: se exige configuracion explicita.
    }
    if (kIsWeb) {
      return 'http://localhost:$_riskEvaluationPort';
    }
    return null;
  }

  /// Origen del microservicio RiskEvaluation.
  ///
  /// No existe una URL publica de produccion confirmada para este servicio, asi
  /// que sin configuracion explicita se lanza un error en lugar de construir
  /// una URL incorrecta reutilizando el host de Users.
  static String get riskEvaluationOrigin {
    if (gateway.enabled) return '${gateway.origin}/re';
    final configurada = _riskEvaluationBaseUrl.replaceAll(RegExp(r'/+$'), '');
    if (configurada.isNotEmpty) return configurada;
    final detectada = _detectarRiskEvaluationHost();
    if (detectada == null) {
      throw StateError(
        'RISK_EVALUATION_BASE_URL no esta configurada. Compila con '
        '--dart-define=RISK_EVALUATION_BASE_URL=https://tu-servicio',
      );
    }
    return detectada;
  }

  /// Envia la evaluacion a RiskEvaluation: JSON camelCase con JWT.
  static String get evaluar => gateway.enabled
      ? gateway.evaluation
      : '$riskEvaluationOrigin/risk-evaluations/';
  static String get historialEvaluaciones =>
      '$_baseUrl/api/v1/evaluaciones/historial';

  // ==========================================
  // ENDPOINTS DE HÁBITOS
  // ==========================================
  static String get habitos => '$_baseUrl/habitos';
  static String get ultimoHabito => '$_baseUrl/habitos/ultimo';

  // ==========================================
  // ENDPOINTS DE ADMIN
  // ==========================================
  static String get adminUsuarios => '$_baseUrl/api/v1/admin/usuarios';
  static String get adminEstadisticas =>
      '$_baseUrl/api/v1/admin/usuarios/estadisticas';

  static String adminUsuarioById(int id) =>
      '$_baseUrl/api/v1/admin/usuarios/$id';
  static String adminCambiarRol(int id) =>
      '$_baseUrl/api/v1/admin/usuarios/$id/rol';
  static String adminEvaluacionById(int id) =>
      '$_baseUrl/api/v1/admin/evaluaciones/$id';

  // ==========================================
  // ENDPOINTS DE MÉDICO
  // ==========================================
  static String get medicoPacientes => '$_baseUrl/api/v1/medico/pacientes';
  static String get medicoEstadisticas =>
      '$_baseUrl/api/v1/medico/estadisticas';
  static String get medicoEvaluacionesRecientes =>
      '$_baseUrl/api/v1/medico/evaluaciones-recientes';
  static String medicoPacienteDetalle(int id) =>
      '$_baseUrl/api/v1/medico/pacientes/$id/detalle';
}

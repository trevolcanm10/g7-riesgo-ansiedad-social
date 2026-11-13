import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_gateway_config.dart';

class AppConstants {
  static const gateway = ApiGatewayConfig(
    baseUrl: String.fromEnvironment('APIM_BASE_URL'),
    subscriptionKey: String.fromEnvironment('APIM_SUBSCRIPTION_KEY'),
  );
  static const String _defaultPort = '5000';
  static const String _prefsKey = 'api_base_url';
  static const String _riskEvaluationPort = '3002';
  static const String _produccionUrl = 'https://ansiedad-riesgo-ml-app.onrender.com';

  static Future<void> init() async {
    // initialization logic
  }

  static String get baseUrl => 'http://localhost:5000';

  static String get registro => 'http://localhost:5000/registro';

  static const String _usersLoginBaseUrl = String.fromEnvironment('USERS_BASE_URL');
  static String get usersOrigin => gateway.enabled
      ? gateway.usersOrigin
      : (_usersLoginBaseUrl.isEmpty ? baseUrl : _usersLoginBaseUrl)
          .replaceAll(RegExp(r'/+$'), '');
  static String get login => '$usersOrigin/users/login';
  static String get usersMe => '$usersOrigin/users/me';
  static String get registroUsers => '$usersOrigin/users';

  static const String _riskEvaluationBaseUrl = String.fromEnvironment('RISK_EVALUATION_BASE_URL');
  static String get riskEvaluationOrigin => 'http://localhost:3002/re';

  static String get evaluar => 'http://localhost:3002/risk-evaluations/';
  static String get historialEvaluaciones => 'http://localhost:3002/risk-evaluations/me/history';

  static String get habitos => 'http://localhost:5000/habitos';
  static String get ultimoHabito => 'http://localhost:5000/habitos/ultimo';

  static String get adminUsuarios => 'http://localhost:5000/api/v1/admin/usuarios';
  static String get adminEstadisticas => 'http://localhost:5000/api/v1/admin/usuarios/estadisticas';
  static String adminUsuarioById(int id) => 'http://localhost:5000/api/v1/admin/usuarios/$id';
  static String adminCambiarRol(int id) => 'http://localhost:5000/api/v1/admin/usuarios/$id/rol';
  static String adminEvaluacionById(int id) => 'http://localhost:5000/api/v1/admin/evaluaciones/$id';

  static String get medicoPacientes => 'http://localhost:5000/api/v1/medico/pacientes';
  static String get medicoEstadisticas => 'http://localhost:5000/api/v1/medico/estadisticas';
  static String get medicoEvaluacionesRecientes => 'http://localhost:5000/api/v1/medico/evaluaciones-recientes';
  static String medicoPacienteDetalle(int id) => 'http://localhost:5000/api/v1/medico/pacientes/$id/detalle';
}

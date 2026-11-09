import 'dart:async';
import 'package:http/http.dart' as http;

import '../../../../core/constants.dart';
import '../../models/evaluacion_model.dart';
import '../../models/recomendacion_model.dart';
import '../../models/resultado_ml_model.dart';
import 'api_service.dart';

/// DataSource remoto para operaciones de evaluaciones.
///
/// Esta clase encapsula todas las llamadas HTTP relacionadas con
/// evaluaciones, convirtiendo JSON a DTOs y viceversa.
class EvaluacionRemoteDataSource {
  final ApiService _apiService;

  EvaluacionRemoteDataSource(this._apiService);

  /// Envia las 15 variables del contrato y obtiene la prediccion de riesgo.
  ///
  /// Usa POST /risk-evaluations/ con JSON camelCase y JWT. Los errores HTTP se
  /// traducen a mensajes comprensibles aqui, para que la capa de presentacion
  /// no dependa de ApiException (misma convencion que el login).
  Future<
    ({
      ResultadoMlModel resultado,
      List<RecomendacionModel> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables) async {
    final Map<String, dynamic> response;
    try {
      response = await _apiService.post(
        AppConstants.evaluar,
        body: variables,
        expectedStatus: 201,
      );
    } on ApiException catch (e) {
      throw Exception(_mensajeHttp(e.statusCode));
    } on TimeoutException {
      throw Exception('El servidor tardo en responder. Intentalo de nuevo.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servicio de evaluacion.');
    } on FormatException {
      throw Exception(
        'El servicio devolvió una respuesta inesperada. Reintenta.',
      );
    }

    // Una respuesta que no cumple el contrato se rechaza: nunca se muestra
    // probabilidad 0 ni riesgo BAJO por defecto.
    late final ResultadoMlModel resultado;
    try {
      resultado = ResultadoMlModel.fromRiskEvaluation(response);
    } on FormatException {
      throw Exception(
        'El servicio devolvió una evaluación incompleta o inválida. Reintenta.',
      );
    }
    return (
      resultado: resultado,
      recomendaciones: resultado.recomendaciones,
      explicacion: response['explanation'] as String?,
    );
  }

  /// Mensaje comprensible segun el codigo HTTP, sin exponer datos sensibles.
  String _mensajeHttp(int statusCode) {
    if (statusCode == 400) {
      return 'Los datos enviados no son validos. Revisa tus respuestas.';
    }
    if (statusCode == 401) {
      return 'Tu sesion expiro. Vuelve a iniciar sesion e intentalo de nuevo.';
    }
    if (statusCode == 403) {
      return 'No tienes permiso para enviar esta evaluación.';
    }
    if (statusCode == 404) {
      return 'El servicio de evaluacion no esta disponible. Contacta al responsable.';
    }
    if (statusCode >= 500) {
      return 'El servicio no esta disponible en este momento. Intentalo mas tarde.';
    }
    return 'No se pudo enviar la evaluacion. Intentalo de nuevo.';
  }

  /// Obtiene el historial de evaluaciones del usuario autenticado.
  Future<List<EvaluacionModel>> obtenerHistorial() async {
    final data = await _apiService.getList(AppConstants.historialEvaluaciones);
    return data
        .map((json) => EvaluacionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}

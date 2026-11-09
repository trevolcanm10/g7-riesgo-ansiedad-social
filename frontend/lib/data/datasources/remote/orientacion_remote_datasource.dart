import 'dart:async';
import '../../../domain/entities/solicitud_orientacion.dart';
import '../../../core/constants.dart';
import 'api_service.dart';

class OrientacionRemoteDataSource {
  final ApiService _apiService;

  OrientacionRemoteDataSource(this._apiService);

  // Mantiene compatibilidad con el entorno local del microservicio Orientacion
  String get _orientacionBaseUrl {
    // Si no está en Gateway, apunta al puerto local 5000 donde corre Flask
    if (AppConstants.gateway.enabled) {
      return '${AppConstants.gateway.origin}/orientacion/solicitudes';
    }
    // Asumimos que corre en 127.0.0.1:5000 localmente o en 10.0.2.2 en Emulador Android
    final baseLocal = AppConstants.baseUrl.replaceAll(RegExp(r'/+$'), '');
    return '$baseLocal/api/v1/orientacion/solicitudes';
  }

  /// Enviar una nueva solicitud confidencial
  Future<OrientacionResponse> enviarSolicitud({
    required String estudianteId,
    required String mensaje,
    required bool comparteEvaluacion,
    int? evaluacionRiesgoId,
  }) async {
    final body = {
      'estudiante_id': estudianteId,
      'mensaje': mensaje,
      'comparte_evaluacion_riesgo': comparteEvaluacion,
      'evaluacion_riesgo_id': ?evaluacionRiesgoId,
    };

    try {
      // POST al endpoint de orientación
      final response = await _apiService.post(
        _orientacionBaseUrl,
        body: body,
        withAuth: false,
      );

      return OrientacionResponse.fromJson(response);
    } on ApiException catch (e) {
      throw Exception('Error al enviar solicitud: ${e.mensaje}');
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor de Orientación.');
    }
  }

  /// Obtener el historial de un estudiante en particular
  Future<List<SolicitudOrientacion>> obtenerHistorial({
    String? estudianteId,
  }) async {
    try {
      final url = (estudianteId != null && estudianteId.isNotEmpty)
          ? '$_orientacionBaseUrl?estudiante_id=${Uri.encodeQueryComponent(estudianteId)}'
          : _orientacionBaseUrl;
      final responseList = await _apiService.getList(url);

      return responseList
          .map((json) => SolicitudOrientacion.fromJson(json))
          .toList();
    } on ApiException catch (e) {
      throw Exception('Error al obtener historial: ${e.mensaje}');
    } catch (_) {
      throw Exception('No se pudo cargar el historial de Orientación.');
    }
  }
}

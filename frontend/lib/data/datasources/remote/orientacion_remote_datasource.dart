import '../../../core/constants.dart';
import '../../../domain/entities/solicitud_orientacion.dart';
import 'api_service.dart';

class OrientacionRemoteDataSource {
  final ApiService _apiService;

  OrientacionRemoteDataSource(this._apiService);

  /// Enviar una nueva solicitud confidencial autenticada por JWT.
  /// `estudiante_id` nunca se envía en el cuerpo: el servidor lo extrae del JWT.
  Future<OrientacionResponse> enviarSolicitud({
    required String mensaje,
    required bool comparteEvaluacion,
    int? evaluacionRiesgoId,
  }) async {
    final body = <String, dynamic>{
      'mensaje': mensaje,
      'comparte_evaluacion_riesgo': comparteEvaluacion,
      if (comparteEvaluacion && evaluacionRiesgoId != null)
        'evaluacion_riesgo_id': evaluacionRiesgoId,
    };

    try {
      final response = await _apiService.post(
        AppConstants.orientacionSolicitudes,
        body: body,
      );
      return OrientacionResponse.fromJson(response);
    } on ApiException catch (e) {
      throw Exception(_mensajeHttp(e));
    } catch (_) {
      throw Exception('No se pudo conectar con el servidor de Orientación.');
    }
  }

  /// Obtener el historial del estudiante autenticado (o bandeja si el rol es UNAYOE).
  Future<List<SolicitudOrientacion>> obtenerHistorial({
    String? estado,
    String? prioridad,
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
      if (estado != null && estado.isNotEmpty) 'estado': estado,
      if (prioridad != null && prioridad.isNotEmpty) 'prioridad': prioridad,
    };
    final uri = Uri.parse(AppConstants.orientacionSolicitudes)
        .replace(queryParameters: params);

    try {
      final responseList = await _apiService.getList(uri.toString());
      return responseList
          .map(
            (json) =>
                SolicitudOrientacion.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } on ApiException catch (e) {
      throw Exception(_mensajeHttp(e));
    } catch (_) {
      throw Exception('No se pudo cargar el historial de Orientación.');
    }
  }

  String _mensajeHttp(ApiException e) {
    switch (e.statusCode) {
      case 400:
        return e.mensaje.isNotEmpty
            ? e.mensaje
            : 'Revisa el contenido de tu solicitud.';
      case 401:
        return 'Tu sesión expiró. Inicia sesión nuevamente.';
      case 403:
        return 'No tienes permisos para realizar esta acción en Orientación.';
      case 404:
        return 'No se encontró la solicitud indicada.';
      case 409:
        return e.mensaje.isNotEmpty
            ? e.mensaje
            : 'La solicitud ya fue atendida previamente.';
      case 429:
        return 'Demasiadas peticiones. Intenta nuevamente en un momento.';
      default:
        if (e.statusCode >= 500) {
          return 'El servicio de Orientación no está disponible temporalmente.';
        }
        return e.mensaje;
    }
  }
}

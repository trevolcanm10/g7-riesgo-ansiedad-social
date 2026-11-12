import 'dart:async';
import 'package:http/http.dart' as http;

import '../../../core/constants.dart';
import '../../../domain/entities/cita.dart';
import '../../models/cita_model.dart';
import 'api_service.dart';

/// DataSource remoto del microservicio Citas (via APIM, prefijo /c).
///
/// Traduce los errores HTTP a mensajes comprensibles. Los 400/404/409 del
/// servicio traen un mensaje de negocio en español (horario ocupado, limite de
/// citas, anticipacion) que se muestra tal cual.
class CitasRemoteDataSource {
  final ApiService _api;

  CitasRemoteDataSource(this._api);

  Future<List<Horario>> horariosLibres() => _ejecutar(() async {
    final data = await _api.getList(AppConstants.citasSlots);
    return data
        .map((e) => CitaModel.horarioFromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<List<Cita>> misCitas() => _ejecutar(() async {
    final data = await _api.getList(AppConstants.citasMias);
    return data
        .map((e) => CitaModel.citaFromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<Cita> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  }) => _ejecutar(() async {
    final body = <String, dynamic>{'slotId': slotId, 'priority': prioridad};
    final texto = motivo?.trim();
    if (texto != null && texto.isNotEmpty) body['reason'] = texto;
    final json = await _api.post(
      AppConstants.citas,
      body: body,
      expectedStatus: 201,
    );
    return CitaModel.citaFromJson(json);
  });

  Future<Cita> cancelar(int citaId) => _ejecutar(() async {
    final json = await _api.patch(
      AppConstants.citaCancelar(citaId),
      body: const {},
    );
    return CitaModel.citaFromJson(json);
  });

  Future<Cita> reprogramar(int citaId, int slotId) => _ejecutar(() async {
    final json = await _api.patch(
      AppConstants.citaReprogramar(citaId),
      body: {'slotId': slotId},
    );
    return CitaModel.citaFromJson(json);
  });

  Future<List<Cita>> agenda({String? estado}) => _ejecutar(() async {
    final url = estado == null
        ? AppConstants.citas
        : '${AppConstants.citas}?status=${Uri.encodeQueryComponent(estado)}';
    final data = await _api.getList(url);
    return data
        .map((e) => CitaModel.citaFromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<List<Horario>> publicarHorarios(
    List<DateTime> inicios, {
    int? personalId,
  }) => _ejecutar(() async {
    final body = <String, dynamic>{
      'startAts': inicios.map((d) => d.toUtc().toIso8601String()).toList(),
    };
    if (personalId != null) body['staffUserId'] = personalId;
    final json = await _api.post(
      AppConstants.citasSlots,
      body: body,
      expectedStatus: 201,
    );
    // ApiService envuelve las listas como {'data': [...]}.
    final lista = json['data'];
    if (lista is! List) throw const FormatException('Respuesta inesperada');
    return lista
        .map((e) => CitaModel.horarioFromJson(e as Map<String, dynamic>))
        .toList();
  });

  Future<Cita> cambiarEstado(int citaId, String estado) => _ejecutar(() async {
    final json = await _api.patch(
      AppConstants.citaEstado(citaId),
      body: {'status': estado},
    );
    return CitaModel.citaFromJson(json);
  });

  Future<RiesgoInasistencia> riesgoInasistencia(int citaId) =>
      _ejecutar(() async {
        final json = await _api.get(AppConstants.citaRiesgo(citaId));
        return CitaModel.riesgoFromJson(json);
      });

  Future<T> _ejecutar<T>(Future<T> Function() accion) async {
    try {
      return await accion();
    } on ApiException catch (e) {
      throw Exception(_mensajeHttp(e));
    } on TimeoutException {
      throw Exception('El servidor tardo en responder. Intentalo de nuevo.');
    } on http.ClientException {
      throw Exception('No se pudo conectar con el servicio de citas.');
    } on FormatException {
      throw Exception(
        'El servicio devolvio una respuesta inesperada. Reintenta.',
      );
    }
  }

  String _mensajeHttp(ApiException e) {
    switch (e.statusCode) {
      case 400:
      case 404:
      case 409:
        return e.mensaje;
      case 401:
        return 'Tu sesion expiro. Vuelve a iniciar sesion.';
      case 403:
        return 'No tienes permiso para esta accion.';
      case 429:
        return 'Hay demasiadas solicitudes seguidas. Espera unos segundos e intentalo de nuevo.';
      default:
        if (e.statusCode >= 500) {
          return 'El servicio de citas no esta disponible. Intentalo mas tarde.';
        }
        return 'No se pudo completar la operacion. Intentalo de nuevo.';
    }
  }
}

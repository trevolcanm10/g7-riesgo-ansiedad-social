class SolicitudOrientacion {
  final int id;
  final int estudianteId;
  final String mensaje;
  final bool comparteEvaluacionRiesgo;
  final int? evaluacionRiesgoId;
  final String? temaSugerido;
  final String? prioridadSugerida;
  final bool urgenciaDetectada;
  final String estado;
  final String? temaConfirmado;
  final String? prioridadConfirmada;
  final String? respuestaEscrita;
  final int? atendidoPor;
  final DateTime? fechaCreacion;
  final DateTime? fechaAtencion;

  SolicitudOrientacion({
    required this.id,
    required this.estudianteId,
    required this.mensaje,
    required this.comparteEvaluacionRiesgo,
    this.evaluacionRiesgoId,
    this.temaSugerido,
    this.prioridadSugerida,
    required this.urgenciaDetectada,
    required this.estado,
    this.temaConfirmado,
    this.prioridadConfirmada,
    this.respuestaEscrita,
    this.atendidoPor,
    this.fechaCreacion,
    this.fechaAtencion,
  });

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.parse(value);
    throw FormatException('Valor entero inválido: $value');
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String && value.trim().isNotEmpty) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  factory SolicitudOrientacion.fromJson(Map<String, dynamic> json) {
    return SolicitudOrientacion(
      id: _parseInt(json['id']),
      estudianteId: _parseInt(json['estudiante_id']),
      mensaje: json['mensaje'] as String? ?? '',
      comparteEvaluacionRiesgo:
          json['comparte_evaluacion_riesgo'] as bool? ?? false,
      evaluacionRiesgoId: _parseNullableInt(json['evaluacion_riesgo_id']),
      temaSugerido: json['tema_sugerido'] as String?,
      prioridadSugerida: json['prioridad_sugerida'] as String?,
      urgenciaDetectada: json['urgencia_detectada'] as bool? ?? false,
      estado: json['estado'] as String? ?? 'pendiente',
      temaConfirmado: json['tema_confirmado'] as String?,
      prioridadConfirmada: json['prioridad_confirmada'] as String?,
      respuestaEscrita: json['respuesta_escrita'] as String?,
      atendidoPor: _parseNullableInt(json['atendido_por']),
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'] as String)
          : null,
      fechaAtencion: json['fecha_atencion'] != null
          ? DateTime.parse(json['fecha_atencion'] as String)
          : null,
    );
  }
}

class AlertaUrgencia {
  final List<String> coincidencias;
  final List<String> lineasAyuda;

  AlertaUrgencia({
    required this.coincidencias,
    required this.lineasAyuda,
  });

  factory AlertaUrgencia.fromJson(Map<String, dynamic> json) {
    return AlertaUrgencia(
      coincidencias: List<String>.from(json['coincidencias'] ?? const []),
      lineasAyuda: List<String>.from(json['lineas_ayuda'] ?? const []),
    );
  }
}

class OrientacionResponse {
  final SolicitudOrientacion solicitud;
  final AlertaUrgencia? alertasUrgencia;

  OrientacionResponse({
    required this.solicitud,
    this.alertasUrgencia,
  });

  factory OrientacionResponse.fromJson(Map<String, dynamic> json) {
    return OrientacionResponse(
      solicitud: SolicitudOrientacion.fromJson(json),
      alertasUrgencia: json['alertas_urgencia'] != null
          ? AlertaUrgencia.fromJson(
              json['alertas_urgencia'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

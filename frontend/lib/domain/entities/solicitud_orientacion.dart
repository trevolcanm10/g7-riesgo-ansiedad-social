class SolicitudOrientacion {
  final int id;
  final String estudianteId;
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
  final String? atendidoPor;
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

  factory SolicitudOrientacion.fromJson(Map<String, dynamic> json) {
    return SolicitudOrientacion(
      id: json['id'],
      estudianteId: json['estudiante_id'],
      mensaje: json['mensaje'],
      comparteEvaluacionRiesgo: json['comparte_evaluacion_riesgo'] ?? false,
      evaluacionRiesgoId: json['evaluacion_riesgo_id'],
      temaSugerido: json['tema_sugerido'],
      prioridadSugerida: json['prioridad_sugerida'],
      urgenciaDetectada: json['urgencia_detectada'] ?? false,
      estado: json['estado'] ?? 'pendiente',
      temaConfirmado: json['tema_confirmado'],
      prioridadConfirmada: json['prioridad_confirmada'],
      respuestaEscrita: json['respuesta_escrita'],
      atendidoPor: json['atendido_por'],
      fechaCreacion: json['fecha_creacion'] != null
          ? DateTime.parse(json['fecha_creacion'])
          : null,
      fechaAtencion: json['fecha_atencion'] != null
          ? DateTime.parse(json['fecha_atencion'])
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
      coincidencias: List<String>.from(json['coincidencias'] ?? []),
      lineasAyuda: List<String>.from(json['lineas_ayuda'] ?? []),
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
          ? AlertaUrgencia.fromJson(json['alertas_urgencia'])
          : null,
    );
  }
}

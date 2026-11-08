import '../../domain/entities/resultado_ml.dart';
import 'recomendacion_model.dart';
import 'reporte_ia_model.dart';

/// DTO (Data Transfer Object) para serializar/deserializar ResultadoMl.
///
/// Esta clase maneja la conversión desde/hacia JSON,
/// y puede convertirse a la entidad de dominio ResultadoMl.
class ResultadoMlModel {
  final int idResultado;
  final int idEvaluacion;
  final int idUsuario;
  final double probabilidadAnsiedad;
  final String nivelRiesgo;
  final String? fechaPrediccion;
  final List<RecomendacionModel> recomendaciones;
  final ReporteIAModel? reporteIA;

  ResultadoMlModel({
    required this.idResultado,
    required this.idEvaluacion,
    required this.idUsuario,
    required this.probabilidadAnsiedad,
    required this.nivelRiesgo,
    this.fechaPrediccion,
    this.recomendaciones = const [],
    this.reporteIA,
  });

  /// Crea un DTO desde JSON (respuesta de la API)
  factory ResultadoMlModel.fromJson(Map<String, dynamic> json) {
    return ResultadoMlModel(
      idResultado: json['id_resultado'] ?? 0,
      idEvaluacion: json['id_evaluacion'] ?? 0,
      idUsuario: json['id_usuario'] ?? 0,
      probabilidadAnsiedad: (json['probabilidad_ansiedad'] ?? 0).toDouble(),
      nivelRiesgo: json['nivel_riesgo'] ?? 'BAJO',
      fechaPrediccion: json['fecha_prediccion'],
      recomendaciones:
          (json['recomendaciones'] as List<dynamic>?)
              ?.map((r) => RecomendacionModel.fromJson(r))
              .toList() ??
          [],
      reporteIA: json['reporte_ia'] != null
          ? ReporteIAModel.fromJson(json['reporte_ia'])
          : null,
    );
  }

  /// Niveles de riesgo aceptados por el contrato de RiskEvaluation.
  static const _niveles = {'BAJO', 'MEDIO', 'ALTO'};

  /// Crea un DTO desde la respuesta de POST /risk-evaluations/.
  ///
  /// La respuesta usa camelCase. Un contrato incompleto o invalido lanza
  /// [FormatException]: nunca se completa con probabilidad 0 ni riesgo BAJO,
  /// porque eso presentaria al usuario un resultado que el servicio no dio.
  factory ResultadoMlModel.fromRiskEvaluation(Map<String, dynamic> json) {
    final id = json['id'];
    if (id is! int || id <= 0) {
      throw const FormatException(
        'La respuesta del servicio no contiene un id valido.',
      );
    }

    final probabilidad = json['anxietyProbability'];
    if (probabilidad is! num ||
        !probabilidad.isFinite ||
        probabilidad < 0 ||
        probabilidad > 1) {
      throw const FormatException(
        'La respuesta del servicio no contiene una probabilidad valida.',
      );
    }

    final nivel = json['riskLevel'];
    final nivelValido = nivel is String && _niveles.contains(nivel);
    if (!nivelValido) {
      throw const FormatException(
        'La respuesta del servicio no contiene un nivel de riesgo valido.',
      );
    }

    final explicacion = json['explanation'];
    if (explicacion is! String || explicacion.trim().isEmpty) {
      throw const FormatException(
        'La respuesta del servicio no contiene una explicacion valida.',
      );
    }

    final recomendacionesJson = json['recommendations'];
    if (recomendacionesJson is! List) {
      throw const FormatException(
        'La respuesta del servicio no contiene recomendaciones validas.',
      );
    }

    final reporteJson = json['aiReport'];
    if (reporteJson is! Map<String, dynamic>) {
      throw const FormatException(
        'La respuesta del servicio no contiene un reporte de IA valido.',
      );
    }
    final userId = json['userId'];
    final createdAt = json['createdAt'];
    if (userId is! int ||
        userId <= 0 ||
        createdAt is! String ||
        DateTime.tryParse(createdAt) == null ||
        recomendacionesJson.any((r) => r is! Map<String, dynamic>)) {
      throw const FormatException(
        'Identidad, fecha o recomendaciones inválidas.',
      );
    }

    return ResultadoMlModel(
      idResultado: id,
      idEvaluacion: id,
      idUsuario: userId,
      probabilidadAnsiedad: probabilidad.toDouble(),
      nivelRiesgo: nivel,
      fechaPrediccion: createdAt,
      recomendaciones: recomendacionesJson
          .map(
            (r) => RecomendacionModel.fromRiskEvaluation(
              r as Map<String, dynamic>,
            ),
          )
          .toList(),
      reporteIA: ReporteIAModel.fromRiskEvaluation(reporteJson),
    );
  }

  /// Convierte el DTO a entidad de dominio
  ResultadoMl toEntity() {
    return ResultadoMl(
      idResultado: idResultado,
      idEvaluacion: idEvaluacion,
      idUsuario: idUsuario,
      probabilidadAnsiedad: probabilidadAnsiedad,
      nivelRiesgo: nivelRiesgo,
      fechaPrediccion: fechaPrediccion,
      recomendaciones: recomendaciones.map((r) => r.toEntity()).toList(),
      reporteIA: reporteIA?.toEntity(),
    );
  }

  /// Crea un DTO desde una entidad de dominio
  factory ResultadoMlModel.fromEntity(ResultadoMl resultado) {
    return ResultadoMlModel(
      idResultado: resultado.idResultado,
      idEvaluacion: resultado.idEvaluacion,
      idUsuario: resultado.idUsuario,
      probabilidadAnsiedad: resultado.probabilidadAnsiedad,
      nivelRiesgo: resultado.nivelRiesgo,
      fechaPrediccion: resultado.fechaPrediccion,
      recomendaciones: resultado.recomendaciones
          .map((r) => RecomendacionModel.fromEntity(r))
          .toList(),
      reporteIA: resultado.reporteIA != null
          ? ReporteIAModel.fromEntity(resultado.reporteIA!)
          : null,
    );
  }

  /// Convierte el DTO a JSON (para enviar a la API)
  Map<String, dynamic> toJson() {
    return {
      'id_resultado': idResultado,
      'id_evaluacion': idEvaluacion,
      'id_usuario': idUsuario,
      'probabilidad_ansiedad': probabilidadAnsiedad,
      'nivel_riesgo': nivelRiesgo,
      'fecha_prediccion': fechaPrediccion,
      'reporte_ia': reporteIA?.toJson(),
      'recomendaciones': recomendaciones.map((r) => r.toJson()).toList(),
    };
  }
}

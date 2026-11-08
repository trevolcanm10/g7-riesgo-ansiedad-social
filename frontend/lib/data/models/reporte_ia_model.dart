import '../../domain/entities/reporte_ia.dart';

/// DTO (Data Transfer Object) para serializar/deserializar ReporteIA.
///
/// Esta clase maneja la conversión desde/hacia JSON,
/// y puede convertirse a la entidad de dominio ReporteIA.
class ReporteIAModel {
  final String resumen;
  final List<String> fortalezas;
  final List<String> factoresPreocupantes;
  final List<String> recomendaciones;
  final List<String> plan7Dias;
  final List<String> temasVideos;
  final List<String> temasLectura;
  final String prioridadIntervencion;
  final String mensajeMotivacional;

  ReporteIAModel({
    required this.resumen,
    required this.fortalezas,
    required this.factoresPreocupantes,
    required this.recomendaciones,
    required this.plan7Dias,
    required this.temasVideos,
    required this.temasLectura,
    required this.prioridadIntervencion,
    required this.mensajeMotivacional,
  });

  /// Crea un DTO desde JSON (respuesta de la API)
  factory ReporteIAModel.fromJson(Map<String, dynamic> json) {
    return ReporteIAModel(
      resumen: json['resumen'] ?? '',
      fortalezas: List<String>.from(json['fortalezas'] ?? []),
      factoresPreocupantes: List<String>.from(
        json['factores_preocupantes'] ?? [],
      ),
      recomendaciones: List<String>.from(json['recomendaciones'] ?? []),
      plan7Dias: List<String>.from(json['plan_7_dias'] ?? []),
      temasVideos: List<String>.from(json['temas_videos'] ?? []),
      temasLectura: List<String>.from(json['temas_lectura'] ?? []),
      prioridadIntervencion: json['prioridad_intervencion'] ?? '',
      mensajeMotivacional: json['mensaje_motivacional'] ?? '',
    );
  }

  /// Crea un DTO desde el aiReport del contrato de RiskEvaluation.
  ///
  /// El backend expone el reporte en camelCase (summary, strengths,
  /// concerningFactors, ...). Se conservan las nueve secciones; una lista
  /// ausente o de tipo incorrecto es un error en lugar de una lista vacia,
  /// para no ocultar contenido que el servicio si devolvio.
  factory ReporteIAModel.fromRiskEvaluation(Map<String, dynamic> json) {
    return ReporteIAModel(
      resumen: _texto(json, 'summary'),
      fortalezas: _lista(json, 'strengths'),
      factoresPreocupantes: _lista(json, 'concerningFactors'),
      recomendaciones: _lista(json, 'recommendations'),
      plan7Dias: _lista(json, 'sevenDayPlan'),
      temasVideos: _lista(json, 'videoTopics'),
      temasLectura: _lista(json, 'readingTopics'),
      prioridadIntervencion: _texto(json, 'priorityIntervention'),
      mensajeMotivacional: _texto(json, 'motivationalMessage'),
    );
  }

  static String _texto(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('El reporte de IA no contiene $key valido.');
    }
    return value;
  }

  static List<String> _lista(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! List ||
        value.any((item) => item is! String || item.trim().isEmpty)) {
      throw FormatException('El reporte de IA no contiene $key valido.');
    }
    return List<String>.from(value);
  }

  /// Convierte el DTO a entidad de dominio
  ReporteIA toEntity() {
    return ReporteIA(
      resumen: resumen,
      fortalezas: fortalezas,
      factoresPreocupantes: factoresPreocupantes,
      recomendaciones: recomendaciones,
      plan7Dias: plan7Dias,
      temasVideos: temasVideos,
      temasLectura: temasLectura,
      prioridadIntervencion: prioridadIntervencion,
      mensajeMotivacional: mensajeMotivacional,
    );
  }

  /// Crea un DTO desde una entidad de dominio
  factory ReporteIAModel.fromEntity(ReporteIA reporte) {
    return ReporteIAModel(
      resumen: reporte.resumen,
      fortalezas: reporte.fortalezas,
      factoresPreocupantes: reporte.factoresPreocupantes,
      recomendaciones: reporte.recomendaciones,
      plan7Dias: reporte.plan7Dias,
      temasVideos: reporte.temasVideos,
      temasLectura: reporte.temasLectura,
      prioridadIntervencion: reporte.prioridadIntervencion,
      mensajeMotivacional: reporte.mensajeMotivacional,
    );
  }

  /// Convierte el DTO a JSON (para enviar a la API)
  Map<String, dynamic> toJson() {
    return {
      'resumen': resumen,
      'fortalezas': fortalezas,
      'factores_preocupantes': factoresPreocupantes,
      'recomendaciones': recomendaciones,
      'plan_7_dias': plan7Dias,
      'temas_videos': temasVideos,
      'temas_lectura': temasLectura,
      'prioridad_intervencion': prioridadIntervencion,
      'mensaje_motivacional': mensajeMotivacional,
    };
  }
}

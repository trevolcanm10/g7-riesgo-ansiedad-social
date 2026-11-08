import 'reporte_ia.dart';
import 'recomendacion.dart';

/// Entidad de dominio que representa el resultado de una evaluación ML.
///
/// Esta es una entidad pura sin dependencias de serialización.
/// La conversión desde/hacia JSON se maneja en la capa Data (DTOs).
class ResultadoMl {
  final int idResultado;
  final int idEvaluacion;
  final int idUsuario;
  final double probabilidadAnsiedad;
  final String nivelRiesgo;
  final String? fechaPrediccion;
  final List<Recomendacion> recomendaciones;
  final ReporteIA? reporteIA;

  ResultadoMl({
    required this.idResultado,
    required this.idEvaluacion,
    required this.idUsuario,
    required this.probabilidadAnsiedad,
    required this.nivelRiesgo,
    this.fechaPrediccion,
    this.recomendaciones = const [],
    this.reporteIA,
  });
}

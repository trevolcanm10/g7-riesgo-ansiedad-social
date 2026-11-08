/// Entidad de dominio que representa el reporte generado por IA (Gemini).
///
/// Esta es una entidad pura sin dependencias de serialización.
/// La conversión desde/hacia JSON se maneja en la capa Data (DTOs).
class ReporteIA {
  final String resumen;
  final List<String> fortalezas;
  final List<String> factoresPreocupantes;
  final List<String> recomendaciones;
  final List<String> plan7Dias;
  final List<String> temasVideos;
  final List<String> temasLectura;
  final String prioridadIntervencion;
  final String mensajeMotivacional;

  ReporteIA({
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
}

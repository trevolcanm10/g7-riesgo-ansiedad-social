/// Entidad de dominio que representa una Recomendación asociada a un nivel de riesgo.
///
/// Esta es una entidad pura sin dependencias de serialización.
/// La conversión desde/hacia JSON se maneja en la capa Data (DTOs).
class Recomendacion {
  final int idRecomendacion;
  final String categoria; // 'BAJO', 'MEDIO', 'ALTO'
  final String titulo;
  final String descripcion;

  Recomendacion({
    required this.idRecomendacion,
    required this.categoria,
    required this.titulo,
    required this.descripcion,
  });
}

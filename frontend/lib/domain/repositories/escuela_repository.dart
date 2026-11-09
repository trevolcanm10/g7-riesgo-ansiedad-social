import '../entities/escuela.dart';

/// Interfaz abstracta del repositorio del catálogo de escuelas.
///
/// Define el contrato para obtener las escuelas profesionales sin depender
/// de detalles de implementación (asset local, base de datos, API, etc.).
abstract class EscuelaRepository {
  /// Obtiene todas las escuelas profesionales ordenadas alfabéticamente,
  /// cada una conservando su facultad y su área académica.
  Future<List<Escuela>> obtenerEscuelas();
}

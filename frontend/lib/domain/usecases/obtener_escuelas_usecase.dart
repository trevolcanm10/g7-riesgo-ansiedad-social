import '../entities/escuela.dart';
import '../repositories/escuela_repository.dart';

/// UseCase para obtener el catálogo de escuelas profesionales.
///
/// Encapsula el acceso al catálogo para que la capa de presentación
/// no conozca los detalles de cómo se carga (en este caso, un asset local).
class ObtenerEscuelasUseCase {
  final EscuelaRepository _escuelaRepository;

  ObtenerEscuelasUseCase(this._escuelaRepository);

  /// Ejecuta la obtención del catálogo de escuelas.
  ///
  /// Retorna la lista ordenada alfabéticamente, sin duplicados exactos.
  Future<List<Escuela>> call() {
    return _escuelaRepository.obtenerEscuelas();
  }
}

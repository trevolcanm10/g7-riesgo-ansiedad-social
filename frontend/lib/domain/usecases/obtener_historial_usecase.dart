import '../entities/evaluacion.dart';
import '../repositories/evaluacion_repository.dart';

/// UseCase para obtener el historial de evaluaciones del usuario.
///
/// Encapsula la lógica de consulta del historial.
class ObtenerHistorialUseCase {
  final EvaluacionRepository _evaluacionRepository;

  ObtenerHistorialUseCase(this._evaluacionRepository);

  /// Ejecuta el caso de uso de obtener historial.
  Future<List<Evaluacion>> call() async {
    return _evaluacionRepository.obtenerHistorial();
  }
}

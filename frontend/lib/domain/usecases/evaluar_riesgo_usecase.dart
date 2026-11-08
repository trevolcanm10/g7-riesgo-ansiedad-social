import '../entities/recomendacion.dart';
import '../entities/resultado_ml.dart';
import '../repositories/evaluacion_repository.dart';

/// UseCase para evaluar el riesgo de ansiedad.
///
/// Encapsula la lógica de envío de variables y obtención del resultado ML.
class EvaluarRiesgoUseCase {
  final EvaluacionRepository _evaluacionRepository;

  EvaluarRiesgoUseCase(this._evaluacionRepository);

  /// Ejecuta el caso de uso de evaluación de riesgo.
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  call(Map<String, num> variables) async {
    return _evaluacionRepository.evaluarRiesgo(variables);
  }
}

import '../entities/evaluacion.dart';
import '../entities/resultado_ml.dart';
import '../entities/recomendacion.dart';

/// Interfaz abstracta del repositorio de evaluaciones.
///
/// Define el contrato para operaciones relacionadas con evaluaciones
/// de riesgo de ansiedad sin depender de detalles de implementación.
abstract class EvaluacionRepository {
  /// Envía las respuestas del cuestionario y obtiene la predicción de riesgo.
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables);

  /// Obtiene el historial de evaluaciones del usuario autenticado.
  Future<List<Evaluacion>> obtenerHistorial();
}

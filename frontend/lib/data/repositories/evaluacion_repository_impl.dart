import '../../../domain/entities/evaluacion.dart';
import '../../../domain/entities/recomendacion.dart';
import '../../../domain/entities/resultado_ml.dart';
import '../../../domain/repositories/evaluacion_repository.dart';
import '../datasources/remote/evaluacion_remote_datasource.dart';

/// Implementación del repositorio de evaluaciones.
///
/// Esta clase implementa la interfaz EvaluacionRepository utilizando
/// el EvaluacionRemoteDataSource para las llamadas HTTP.
class EvaluacionRepositoryImpl implements EvaluacionRepository {
  final EvaluacionRemoteDataSource _remoteDataSource;

  EvaluacionRepositoryImpl(this._remoteDataSource);

  @override
  Future<
    ({
      ResultadoMl resultado,
      List<Recomendacion> recomendaciones,
      String? explicacion,
    })
  >
  evaluarRiesgo(Map<String, num> variables) async {
    final result = await _remoteDataSource.evaluarRiesgo(variables);
    return (
      resultado: result.resultado.toEntity(),
      recomendaciones: result.recomendaciones.map((r) => r.toEntity()).toList(),
      explicacion: result.explicacion,
    );
  }

  @override
  Future<List<Evaluacion>> obtenerHistorial() async {
    final evaluaciones = await _remoteDataSource.obtenerHistorial();
    return evaluaciones.map((e) => e.toEntity()).toList();
  }
}

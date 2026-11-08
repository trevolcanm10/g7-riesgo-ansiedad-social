import '../repositories/medico_repository.dart';

/// UseCase para obtener las evaluaciones recientes de los pacientes.
///
/// Encapsula la lógica de consulta de evaluaciones recientes.
class ObtenerEvaluacionesRecientesUseCase {
  final MedicoRepository _medicoRepository;

  ObtenerEvaluacionesRecientesUseCase(this._medicoRepository);

  /// Ejecuta el caso de uso de obtener evaluaciones recientes.
  Future<List<Map<String, dynamic>>> call() async {
    return _medicoRepository.obtenerEvaluacionesRecientes();
  }
}

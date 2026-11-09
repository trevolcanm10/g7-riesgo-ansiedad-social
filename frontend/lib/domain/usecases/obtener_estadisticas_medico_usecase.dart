import '../repositories/medico_repository.dart';

/// UseCase para obtener estadísticas del médico.
///
/// Encapsula la lógica de consulta de estadísticas generales.
class ObtenerEstadisticasMedicoUseCase {
  final MedicoRepository _medicoRepository;

  ObtenerEstadisticasMedicoUseCase(this._medicoRepository);

  /// Ejecuta el caso de uso de obtener estadísticas.
  Future<Map<String, dynamic>> call() async {
    return _medicoRepository.obtenerEstadisticas();
  }
}

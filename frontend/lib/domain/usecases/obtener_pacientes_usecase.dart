import '../repositories/medico_repository.dart';

/// UseCase para obtener la lista de pacientes del médico.
///
/// Encapsula la lógica de consulta de pacientes.
class ObtenerPacientesUseCase {
  final MedicoRepository _medicoRepository;

  ObtenerPacientesUseCase(this._medicoRepository);

  /// Ejecuta el caso de uso de obtener pacientes.
  Future<List<Map<String, dynamic>>> call() async {
    return _medicoRepository.obtenerPacientes();
  }
}

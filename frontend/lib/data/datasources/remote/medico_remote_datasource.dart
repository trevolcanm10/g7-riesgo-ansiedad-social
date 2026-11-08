import '../../../../core/constants.dart';
import 'api_service.dart';

/// DataSource remoto para operaciones del rol Médico.
///
/// Esta clase encapsula todas las llamadas HTTP relacionadas con
/// estadísticas, pacientes y evaluaciones médicas.
class MedicoRemoteDataSource {
  final ApiService _apiService;

  MedicoRemoteDataSource(this._apiService);

  /// Obtiene estadísticas generales del médico.
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    return _apiService.get(AppConstants.medicoEstadisticas);
  }

  /// Obtiene la lista de pacientes del médico.
  Future<List<Map<String, dynamic>>> obtenerPacientes() async {
    final data = await _apiService.getList(AppConstants.medicoPacientes);
    return data.cast<Map<String, dynamic>>();
  }

  /// Obtiene las evaluaciones recientes de los pacientes.
  Future<List<Map<String, dynamic>>> obtenerEvaluacionesRecientes() async {
    final data = await _apiService.getList(
      AppConstants.medicoEvaluacionesRecientes,
    );
    return data.cast<Map<String, dynamic>>();
  }
}

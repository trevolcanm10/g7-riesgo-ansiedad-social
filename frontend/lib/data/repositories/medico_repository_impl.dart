import '../../../domain/repositories/medico_repository.dart';
import '../datasources/remote/medico_remote_datasource.dart';

/// Implementación del repositorio para el rol Médico.
///
/// Esta clase implementa la interfaz MedicoRepository utilizando
/// el MedicoRemoteDataSource para las llamadas HTTP.
class MedicoRepositoryImpl implements MedicoRepository {
  final MedicoRemoteDataSource _remoteDataSource;

  MedicoRepositoryImpl(this._remoteDataSource);

  @override
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    return _remoteDataSource.obtenerEstadisticas();
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerPacientes() async {
    return _remoteDataSource.obtenerPacientes();
  }

  @override
  Future<List<Map<String, dynamic>>> obtenerEvaluacionesRecientes() async {
    return _remoteDataSource.obtenerEvaluacionesRecientes();
  }
}

import '../../../domain/entities/escuela.dart';
import '../../../domain/repositories/escuela_repository.dart';
import '../datasources/local/escuela_local_datasource.dart';

/// Implementación del repositorio del catálogo de escuelas.
///
/// Esta clase implementa la interfaz EscuelaRepository utilizando
/// el EscuelaLocalDataSource (asset local, sin HTTP ni base de datos).
class EscuelaRepositoryImpl implements EscuelaRepository {
  final EscuelaLocalDataSource _localDataSource;

  EscuelaRepositoryImpl(this._localDataSource);

  @override
  Future<List<Escuela>> obtenerEscuelas() async {
    final modelos = await _localDataSource.obtenerEscuelas();
    return modelos.map((modelo) => modelo.toEntity()).toList();
  }
}

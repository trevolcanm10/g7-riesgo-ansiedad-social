import '../../domain/entities/cita.dart';
import '../../domain/repositories/citas_repository.dart';
import '../datasources/remote/citas_remote_datasource.dart';

class CitasRepositoryImpl implements CitasRepository {
  final CitasRemoteDataSource _remote;

  CitasRepositoryImpl(this._remote);

  @override
  Future<List<Horario>> horariosLibres() => _remote.horariosLibres();

  @override
  Future<List<Cita>> misCitas() => _remote.misCitas();

  @override
  Future<Cita> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  }) => _remote.solicitar(slotId: slotId, prioridad: prioridad, motivo: motivo);

  @override
  Future<Cita> cancelar(int citaId) => _remote.cancelar(citaId);

  @override
  Future<Cita> reprogramar(int citaId, int slotId) =>
      _remote.reprogramar(citaId, slotId);
}

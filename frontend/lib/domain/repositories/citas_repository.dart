import '../entities/cita.dart';

/// Contrato del repositorio de citas (microservicio Citas).
abstract class CitasRepository {
  /// Horarios libres proximos (por defecto los siguientes 14 dias).
  Future<List<Horario>> horariosLibres();

  /// Citas del estudiante autenticado.
  Future<List<Cita>> misCitas();

  Future<Cita> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  });

  Future<Cita> cancelar(int citaId);

  Future<Cita> reprogramar(int citaId, int slotId);
}

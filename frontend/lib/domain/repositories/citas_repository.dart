import '../entities/cita.dart';

/// Contrato del repositorio de citas (microservicio Citas).
abstract class CitasRepository {
  /// Horarios libres proximos (por defecto los siguientes 14 dias).
  Future<List<Horario>> horariosLibres();

  /// Citas del estudiante autenticado.
  Future<List<Cita>> misCitas();

  /// Recordatorios de las proximas citas del estudiante autenticado.
  Future<List<Recordatorio>> misRecordatorios();

  Future<Cita> solicitar({
    required int slotId,
    required String prioridad,
    String? motivo,
  });

  Future<Cita> cancelar(int citaId);

  Future<Cita> reprogramar(int citaId, int slotId);

  // --- Personal UNAYOE / administrador ---

  /// Agenda del personal (el administrador ve todas). [estado] filtra.
  Future<List<Cita>> agenda({String? estado});

  /// Publica horarios de 30 min. [personalId] es obligatorio solo para admin.
  Future<List<Horario>> publicarHorarios(
    List<DateTime> inicios, {
    int? personalId,
  });

  Future<Cita> cambiarEstado(int citaId, String estado);

  Future<RiesgoInasistencia> riesgoInasistencia(int citaId);
}

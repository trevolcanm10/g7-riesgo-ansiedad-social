/// Horario libre publicado por UNAYOE (bloque fijo de 30 minutos).
class Horario {
  final int id;
  final int staffUserId;
  final DateTime inicio;
  final DateTime fin;

  const Horario({
    required this.id,
    required this.staffUserId,
    required this.inicio,
    required this.fin,
  });
}

/// Cita de un estudiante con UNAYOE.
class Cita {
  static const solicitada = 'SOLICITADA';
  static const confirmada = 'CONFIRMADA';
  static const atendida = 'ATENDIDA';
  static const noAsistio = 'NO_ASISTIO';
  static const cancelada = 'CANCELADA';

  /// Anticipacion minima para cancelar o reprogramar (misma regla que Citas).
  static const horasMinimasParaCambiar = 12;

  final int id;
  final int slotId;
  final DateTime inicio;
  final DateTime fin;
  final String estado;
  final String prioridad;
  final String? motivo;
  final int reprogramaciones;
  final int? estudianteId;
  final int? personalId;

  const Cita({
    required this.id,
    required this.slotId,
    required this.inicio,
    required this.fin,
    required this.estado,
    required this.prioridad,
    this.motivo,
    this.reprogramaciones = 0,
    this.estudianteId,
    this.personalId,
  });

  /// Prioridad informativa que se envía al solicitar: ALTA solo si el resultado
  /// del test fue de riesgo alto. No cambia permisos ni orden en el servidor.
  static String prioridadPara(String? nivelRiesgo) =>
      nivelRiesgo?.toUpperCase() == 'ALTO' ? 'ALTA' : 'NORMAL';

  bool get activa => estado == solicitada || estado == confirmada;

  /// Solo orienta la interfaz; la regla real la valida el servidor.
  bool puedeModificar(DateTime ahora) =>
      activa &&
      inicio.difference(ahora) >= const Duration(hours: horasMinimasParaCambiar);
}

/// Estimacion orientativa de inasistencia. Solo sirve para decidir un
/// recordatorio: nunca para negar ni retrasar una cita.
class RiesgoInasistencia {
  final double probabilidad;
  final List<String> factores;
  final String modelo;
  final String? nota;

  const RiesgoInasistencia({
    required this.probabilidad,
    required this.factores,
    required this.modelo,
    this.nota,
  });
}

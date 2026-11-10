import '../../domain/entities/cita.dart';

/// Conversion JSON -> entidades del servicio Citas.
///
/// Las fechas llegan en UTC (sufijo Z); se convierten a hora local solo al
/// mostrarlas. Una respuesta incompleta lanza [FormatException].
class CitaModel {
  static Horario horarioFromJson(Map<String, dynamic> json) => Horario(
    id: _entero(json, 'id'),
    staffUserId: _entero(json, 'staffUserId'),
    inicio: _fecha(json, 'startAt'),
    fin: _fecha(json, 'endAt'),
  );

  static Cita citaFromJson(Map<String, dynamic> json) => Cita(
    id: _entero(json, 'id'),
    slotId: _entero(json, 'slotId'),
    inicio: _fecha(json, 'startAt'),
    fin: _fecha(json, 'endAt'),
    estado: _texto(json, 'status'),
    prioridad: (json['priority'] as String?) ?? 'NORMAL',
    motivo: json['reason'] as String?,
    reprogramaciones: (json['rescheduleCount'] as num?)?.toInt() ?? 0,
    estudianteId: (json['studentUserId'] as num?)?.toInt(),
    personalId: (json['staffUserId'] as num?)?.toInt(),
  );

  static RiesgoInasistencia riesgoFromJson(Map<String, dynamic> json) {
    final p = json['noShowProbability'];
    if (p is! num) {
      throw const FormatException('Campo invalido: noShowProbability');
    }
    return RiesgoInasistencia(
      probabilidad: p.toDouble().clamp(0.0, 1.0),
      factores: ((json['factors'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      modelo: (json['model'] as String?) ?? 'desconocido',
      nota: json['note'] as String?,
    );
  }

  static int _entero(Map<String, dynamic> json, String clave) {
    final valor = json[clave];
    if (valor is num) return valor.toInt();
    throw FormatException('Campo invalido: $clave');
  }

  static String _texto(Map<String, dynamic> json, String clave) {
    final valor = json[clave];
    if (valor is String && valor.isNotEmpty) return valor;
    throw FormatException('Campo invalido: $clave');
  }

  static DateTime _fecha(Map<String, dynamic> json, String clave) =>
      DateTime.parse(_texto(json, clave));
}

/// Formato de fechas en español para las pantallas de citas (sin `intl`).
const _dias = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _dos(int n) => n.toString().padLeft(2, '0');

/// "mié 20 nov"
String fechaCorta(DateTime utc) {
  final d = utc.toLocal();
  return '${_dias[d.weekday - 1]} ${d.day} ${_meses[d.month - 1]}';
}

/// "10:30"
String hora(DateTime utc) {
  final d = utc.toLocal();
  return '${_dos(d.hour)}:${_dos(d.minute)}';
}

/// Clave de dia local para agrupar horarios.
DateTime soloDia(DateTime utc) {
  final d = utc.toLocal();
  return DateTime(d.year, d.month, d.day);
}

String etiquetaEstado(String estado) {
  switch (estado) {
    case 'SOLICITADA':
      return 'Solicitada';
    case 'CONFIRMADA':
      return 'Confirmada';
    case 'ATENDIDA':
      return 'Atendida';
    case 'NO_ASISTIO':
      return 'No asistió';
    case 'CANCELADA':
      return 'Cancelada';
    default:
      return estado;
  }
}

/// "menos de 1 hora", "1 hora", "20 horas"
String textoFaltan(int horas) {
  if (horas < 1) return 'menos de 1 hora';
  return horas == 1 ? '1 hora' : '$horas horas';
}

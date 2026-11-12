/// Reglas de generacion de horarios (duracion fija de 30 min, igual que Citas).
const minutosPorCita = 30;
const maxHorariosPorPublicacion = 50;

/// Inicios de bloques de 30 min entre [desde] y [hasta]. El ultimo bloque debe
/// terminar a mas tardar en [hasta]. Devuelve vacio si el rango no es valido.
List<DateTime> generarInicios(DateTime desde, DateTime hasta) {
  final inicios = <DateTime>[];
  var t = desde;
  while (!t.add(const Duration(minutes: minutosPorCita)).isAfter(hasta)) {
    inicios.add(t);
    t = t.add(const Duration(minutes: minutosPorCita));
  }
  return inicios;
}

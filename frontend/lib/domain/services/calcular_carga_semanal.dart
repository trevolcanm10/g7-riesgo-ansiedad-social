import '../entities/actividad_academica.dart';

enum NivelCargaAcademica { baja, moderada, alta }

class CargaSemanal {
  final DateTime lunes;
  final DateTime domingo;
  final double horasConocidas;
  final int pendientes;
  final int completadas;
  final bool estimacionParcial;
  final NivelCargaAcademica nivel;

  const CargaSemanal({
    required this.lunes,
    required this.domingo,
    required this.horasConocidas,
    required this.pendientes,
    required this.completadas,
    required this.estimacionParcial,
    required this.nivel,
  });
}

/// Calcula horas conocidas de actividades pendientes con entrega en la semana
/// local de [fechaSeleccionada]. No distribuye las horas entre días.
CargaSemanal calcularCargaSemanal(
  Iterable<ActividadAcademica> actividades,
  DateTime fechaSeleccionada,
) {
  final fechaLocal = fechaSeleccionada.toLocal();
  final dia = DateTime(fechaLocal.year, fechaLocal.month, fechaLocal.day);
  final lunes = dia.subtract(Duration(days: dia.weekday - DateTime.monday));
  final domingo = lunes.add(const Duration(days: 6));
  var horas = 0.0;
  var pendientes = 0;
  var completadas = 0;
  var parcial = false;

  for (final actividad in actividades) {
    final entregaLocal = actividad.fecha.toLocal();
    final entrega = DateTime(entregaLocal.year, entregaLocal.month, entregaLocal.day);
    if (entrega.isBefore(lunes) || entrega.isAfter(domingo)) continue;
    if (actividad.completada) {
      completadas++;
      continue;
    }
    pendientes++;
    final duracion = actividad.duracionEstimadaHoras;
    if (duracion == null || !duracion.isFinite || duracion < 0) {
      parcial = true;
    } else {
      horas += duracion;
    }
  }

  return CargaSemanal(
    lunes: lunes,
    domingo: domingo,
    horasConocidas: horas,
    pendientes: pendientes,
    completadas: completadas,
    estimacionParcial: parcial,
    nivel: horas > 20
        ? NivelCargaAcademica.alta
        : horas >= 10
            ? NivelCargaAcademica.moderada
            : NivelCargaAcademica.baja,
  );
}

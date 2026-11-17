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
    final entrega = DateTime(
      entregaLocal.year,
      entregaLocal.month,
      entregaLocal.day,
    );
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

/// Resume las actividades pendientes de la semana para el clasificador remoto.
Map<String, num> indicadoresCargaSemanal(
  Iterable<ActividadAcademica> actividades,
  DateTime fechaSeleccionada, {
  DateTime? ahora,
}) {
  final semana = calcularCargaSemanal(actividades, fechaSeleccionada);
  final hoy = (ahora ?? DateTime.now()).toLocal();
  final horasPorDia = <DateTime, double>{};
  final dias = <DateTime>{};
  var examenes = 0;
  var entregas = 0;
  var urgentes = 0;
  var prioridadAlta = 0;
  var sinDuracion = 0;
  for (final actividad in actividades) {
    final fecha = actividad.fecha.toLocal();
    final dia = DateTime(fecha.year, fecha.month, fecha.day);
    if (actividad.completada ||
        dia.isBefore(semana.lunes) ||
        dia.isAfter(semana.domingo)) {
      continue;
    }
    dias.add(dia);
    if (actividad.tipo.toLowerCase() == 'examen') examenes++;
    if (actividad.tipo.toLowerCase() == 'tarea' ||
        actividad.tipo.toLowerCase() == 'proyecto') {
      entregas++;
    }
    if (!dia.isBefore(DateTime(hoy.year, hoy.month, hoy.day)) &&
        dia.isBefore(hoy.add(const Duration(hours: 48)))) {
      urgentes++;
    }
    if (actividad.prioridad.toLowerCase() == 'alta') prioridadAlta++;
    final horas = actividad.duracionEstimadaHoras;
    if (horas == null || !horas.isFinite || horas < 0) {
      sinDuracion++;
    } else {
      horasPorDia[dia] = (horasPorDia[dia] ?? 0) + horas;
    }
  }
  final horasOrdenadas = horasPorDia.values.toList()
    ..sort((a, b) => b.compareTo(a));
  final topTres = horasOrdenadas.take(3).fold<double>(0, (a, b) => a + b);
  return {
    'horas_totales': semana.horasConocidas,
    'num_actividades': semana.pendientes,
    'num_examenes': examenes,
    'num_entregas': entregas,
    'num_urgentes_48h': urgentes,
    'num_prioridad_alta': prioridadAlta,
    'dias_con_actividades': dias.length,
    'max_horas_dia': horasOrdenadas.isEmpty ? 0 : horasOrdenadas.first,
    'concentracion_3dias': semana.horasConocidas == 0
        ? 0
        : topTres / semana.horasConocidas,
    'num_sin_duracion': sinDuracion,
  };
}

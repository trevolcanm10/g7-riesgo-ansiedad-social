import 'package:flutter_test/flutter_test.dart';
import 'package:ansiedad_ml_app/domain/entities/actividad_academica.dart';
import 'package:ansiedad_ml_app/domain/services/calcular_carga_semanal.dart';

ActividadAcademica actividad(DateTime fecha, {double? horas, bool completada = false}) =>
    ActividadAcademica(
      id: '${fecha.microsecondsSinceEpoch}-$horas-$completada',
      titulo: 'Actividad', curso: 'Curso', tipo: 'tarea', fecha: fecha,
      hora: null, duracionEstimadaHoras: horas, prioridad: 'media',
      descripcion: '', completada: completada,
    );

void main() {
  final miercoles = DateTime(2026, 11, 11);

  test('semana local inclusiva de lunes a domingo y límites de 10 y 20 horas', () {
    final lunes = DateTime(2026, 11, 9);
    final domingo = DateTime(2026, 11, 15);
    final anterior = DateTime(2026, 11, 8);
    final siguiente = DateTime(2026, 11, 16);
    final diez = calcularCargaSemanal([
      actividad(lunes, horas: 4), actividad(domingo, horas: 6),
      actividad(anterior, horas: 100), actividad(siguiente, horas: 100),
    ], miercoles);
    expect(diez.lunes, lunes);
    expect(diez.domingo, domingo);
    expect(diez.horasConocidas, 10);
    expect(diez.pendientes, 2);
    expect(diez.nivel, NivelCargaAcademica.moderada);

    final veinte = calcularCargaSemanal([actividad(lunes, horas: 20)], miercoles);
    expect(veinte.nivel, NivelCargaAcademica.moderada);
    expect(calcularCargaSemanal([actividad(lunes, horas: 9.99)], miercoles).nivel, NivelCargaAcademica.baja);
    expect(calcularCargaSemanal([actividad(lunes, horas: 20.01)], miercoles).nivel, NivelCargaAcademica.alta);
  });

  test('excluye duraciones ausentes o inválidas y actividades completadas', () {
    final result = calcularCargaSemanal([
      actividad(miercoles, horas: 3),
      actividad(miercoles),
      actividad(miercoles, horas: -1),
      actividad(miercoles, horas: double.infinity),
      actividad(miercoles, horas: 99, completada: true),
    ], miercoles);
    expect(result.horasConocidas, 3);
    expect(result.pendientes, 4);
    expect(result.completadas, 1);
    expect(result.estimacionParcial, isTrue);
    expect(result.nivel, NivelCargaAcademica.baja);
  });

  test('al cambiar estado o borrar una actividad se recalcula con la nueva lista', () {
    final original = actividad(miercoles, horas: 21);
    expect(calcularCargaSemanal([original], miercoles).nivel, NivelCargaAcademica.alta);
    final completada = original.copyWith(completada: true);
    expect(calcularCargaSemanal([completada], miercoles).horasConocidas, 0);
    expect(calcularCargaSemanal([completada], miercoles).completadas, 1);
    expect(calcularCargaSemanal([], miercoles).pendientes, 0);
  });
}

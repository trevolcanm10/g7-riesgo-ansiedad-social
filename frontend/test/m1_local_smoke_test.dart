import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ansiedad_ml_app/data/repositories/agenda_local_repository.dart';
import 'package:ansiedad_ml_app/domain/entities/actividad_academica.dart';
import 'package:ansiedad_ml_app/domain/services/calcular_carga_semanal.dart';

void main() {
  test('agenda local aislada: crear, consultar, editar, completar, reactivar y eliminar', () async {
    SharedPreferences.setMockInitialValues({});
    const repo = AgendaLocalRepository(987654321);
    const other = AgendaLocalRepository(987654322);
    final day = DateTime(2026, 11, 12);
    final item = ActividadAcademica(id: 'smoke-1', titulo: 'Tarea', curso: 'Curso', tipo: 'tarea',
      fecha: day, hora: null, duracionEstimadaHoras: 10, prioridad: 'media', descripcion: '', completada: false);
    await repo.guardar([item]);
    expect((await repo.obtener()).single.titulo, 'Tarea');
    expect(await other.obtener(), isEmpty);
    expect(calcularCargaSemanal(await repo.obtener(), day).nivel, NivelCargaAcademica.moderada);
    final edited = ActividadAcademica(id: item.id, titulo: 'Tarea editada', curso: item.curso, tipo: item.tipo,
      fecha: day, hora: null, duracionEstimadaHoras: 21, prioridad: 'alta', descripcion: '', completada: false);
    await repo.guardar([edited]);
    expect((await repo.obtener()).single.titulo, 'Tarea editada');
    expect(calcularCargaSemanal(await repo.obtener(), day).nivel, NivelCargaAcademica.alta);
    await repo.guardar([edited.copyWith(completada: true)]);
    expect(calcularCargaSemanal(await repo.obtener(), day).completadas, 1);
    expect(calcularCargaSemanal(await repo.obtener(), day).horasConocidas, 0);
    await repo.guardar([edited.copyWith(completada: false)]);
    expect(calcularCargaSemanal(await repo.obtener(), day).pendientes, 1);
    await repo.guardar([]);
    expect(await repo.obtener(), isEmpty);
  });
}

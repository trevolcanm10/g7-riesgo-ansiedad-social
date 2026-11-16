import '../entities/actividad_academica.dart';

abstract class AgendaRepository {
  Future<List<ActividadAcademica>> obtener();
  Future<void> guardar(List<ActividadAcademica> actividades);
}

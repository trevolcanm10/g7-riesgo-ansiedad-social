import '../entities/evaluacion.dart';

/// Interfaz abstracta del repositorio para el rol Médico.
///
/// Define el contrato para operaciones de gestión de pacientes
/// y estadísticas médicas sin depender de detalles de implementación.
abstract class MedicoRepository {
  /// Obtiene estadísticas generales del médico.
  Future<Map<String, dynamic>> obtenerEstadisticas();

  /// Obtiene la lista de pacientes del médico.
  Future<List<Map<String, dynamic>>> obtenerPacientes();

  /// Obtiene las evaluaciones recientes de los pacientes.
  Future<List<Map<String, dynamic>>> obtenerEvaluacionesRecientes();
}

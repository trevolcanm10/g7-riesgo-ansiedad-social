import 'package:flutter_test/flutter_test.dart';
import 'package:ansiedad_ml_app/domain/entities/evaluacion.dart';
import 'package:ansiedad_ml_app/domain/entities/resultado_ml.dart';
import 'package:ansiedad_ml_app/presentation/pages/evaluacion/historial_screen.dart';

Evaluacion evaluacion(int id, String? fecha, double? probabilidad) => Evaluacion(
  idEvaluacion: id, idUsuario: 1, fechaRealizacion: fecha,
  phq9Score: 0, gad7Score: 0, sleepHours: 0, exerciseFreq: 0,
  socialActivity: 0, onlineStress: 0, gpa: 0, familySupport: 0,
  screenTime: 0, academicStress: 0, dietQuality: 0,
  selfEfficacy: 0, peerRelationship: 0, financialStress: 0,
  sleepQuality: 0,
  resultado: probabilidad == null ? null : ResultadoMl(
    idResultado: id, idEvaluacion: id, idUsuario: 1,
    probabilidadAnsiedad: probabilidad, nivelRiesgo: 'BAJO',
  ),
);

void main() {
  test('ordena cronológicamente con desempate estable y conserva registros', () {
    final records = [
      evaluacion(3, null, 0.3),
      evaluacion(2, '2026-11-12T10:00:00', 0.2),
      evaluacion(4, '2026-11-12T10:00:00', 0.4),
      evaluacion(1, '2026-11-10T10:00:00', 0.1),
    ];
    expect(ordenarHistorialCronologico(records).map((e) => e.idEvaluacion), [1, 2, 4, 3]);
    expect(records.first.idEvaluacion, 3);
  });

  test('grafica solo fechas y probabilidades válidas; admite cero y uno', () {
    expect(puntosDeRiesgo([]), isEmpty);
    final records = [
      evaluacion(1, '2026-11-10', 0),
      evaluacion(2, '2026-11-11', 1),
      evaluacion(3, '2026-11-12', null),
      evaluacion(4, 'fecha inválida', 0.5),
      evaluacion(5, '2026-11-13', double.nan),
      evaluacion(6, '2026-11-14', 1.2),
    ];
    expect(puntosDeRiesgo(records).map((e) => e.idEvaluacion), [1, 2]);
    expect(puntosDeRiesgo([records.first]).length, 1);
  });
}

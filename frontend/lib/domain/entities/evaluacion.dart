import 'resultado_ml.dart';

/// Entidad de dominio que representa una Evaluación de riesgo de ansiedad.
///
/// Esta es una entidad pura sin dependencias de serialización.
/// La conversión desde/hacia JSON se maneja en la capa Data (DTOs).
class Evaluacion {
  final int idEvaluacion;
  final int idUsuario;
  final String? fechaRealizacion;

  // 15 variables del modelo ML
  final double phq9Score;
  final double gad7Score;
  final double sleepHours;
  final double exerciseFreq;
  final double socialActivity;
  final double onlineStress;
  final double gpa;
  final double familySupport;
  final double screenTime;
  final double academicStress;
  final double dietQuality;
  final double selfEfficacy;
  final double peerRelationship;
  final double financialStress;
  final double sleepQuality;

  final ResultadoMl? resultado;

  Evaluacion({
    required this.idEvaluacion,
    required this.idUsuario,
    this.fechaRealizacion,
    required this.phq9Score,
    required this.gad7Score,
    required this.sleepHours,
    required this.exerciseFreq,
    required this.socialActivity,
    required this.onlineStress,
    required this.gpa,
    required this.familySupport,
    required this.screenTime,
    required this.academicStress,
    required this.dietQuality,
    required this.selfEfficacy,
    required this.peerRelationship,
    required this.financialStress,
    required this.sleepQuality,
    this.resultado,
  });
}

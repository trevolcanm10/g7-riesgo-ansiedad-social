import '../../domain/entities/evaluacion.dart';
import 'resultado_ml_model.dart';

/// DTO (Data Transfer Object) para serializar/deserializar Evaluacion.
///
/// Esta clase maneja la conversión desde/hacia JSON,
/// y puede convertirse a la entidad de dominio Evaluacion.
class EvaluacionModel {
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

  final ResultadoMlModel? resultado;

  EvaluacionModel({
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

  /// Crea un DTO desde JSON (respuesta de la API)
  factory EvaluacionModel.fromJson(Map<String, dynamic> json) {
    return EvaluacionModel(
      idEvaluacion: json['id_evaluacion'] ?? 0,
      idUsuario: json['id_usuario'] ?? 0,
      fechaRealizacion: json['fecha_realizacion'],
      phq9Score: (json['phq9_score'] ?? 0).toDouble(),
      gad7Score: (json['gad7_score'] ?? 0).toDouble(),
      sleepHours: (json['sleep_hours'] ?? 0).toDouble(),
      exerciseFreq: (json['exercise_freq'] ?? 0).toDouble(),
      socialActivity: (json['social_activity'] ?? 0).toDouble(),
      onlineStress: (json['online_stress'] ?? 0).toDouble(),
      gpa: (json['gpa'] ?? 0).toDouble(),
      familySupport: (json['family_support'] ?? 0).toDouble(),
      screenTime: (json['screen_time'] ?? 0).toDouble(),
      academicStress: (json['academic_stress'] ?? 0).toDouble(),
      dietQuality: (json['diet_quality'] ?? 0).toDouble(),
      selfEfficacy: (json['self_efficacy'] ?? 0).toDouble(),
      peerRelationship: (json['peer_relationship'] ?? 0).toDouble(),
      financialStress: (json['financial_stress'] ?? 0).toDouble(),
      sleepQuality: (json['sleep_quality'] ?? 0).toDouble(),
      resultado: json['resultado'] != null
          ? ResultadoMlModel.fromJson(json['resultado'])
          : null,
    );
  }

  /// Convierte el DTO a entidad de dominio
  Evaluacion toEntity() {
    return Evaluacion(
      idEvaluacion: idEvaluacion,
      idUsuario: idUsuario,
      fechaRealizacion: fechaRealizacion,
      phq9Score: phq9Score,
      gad7Score: gad7Score,
      sleepHours: sleepHours,
      exerciseFreq: exerciseFreq,
      socialActivity: socialActivity,
      onlineStress: onlineStress,
      gpa: gpa,
      familySupport: familySupport,
      screenTime: screenTime,
      academicStress: academicStress,
      dietQuality: dietQuality,
      selfEfficacy: selfEfficacy,
      peerRelationship: peerRelationship,
      financialStress: financialStress,
      sleepQuality: sleepQuality,
      resultado: resultado?.toEntity(),
    );
  }

  /// Crea un DTO desde una entidad de dominio
  factory EvaluacionModel.fromEntity(Evaluacion evaluacion) {
    return EvaluacionModel(
      idEvaluacion: evaluacion.idEvaluacion,
      idUsuario: evaluacion.idUsuario,
      fechaRealizacion: evaluacion.fechaRealizacion,
      phq9Score: evaluacion.phq9Score,
      gad7Score: evaluacion.gad7Score,
      sleepHours: evaluacion.sleepHours,
      exerciseFreq: evaluacion.exerciseFreq,
      socialActivity: evaluacion.socialActivity,
      onlineStress: evaluacion.onlineStress,
      gpa: evaluacion.gpa,
      familySupport: evaluacion.familySupport,
      screenTime: evaluacion.screenTime,
      academicStress: evaluacion.academicStress,
      dietQuality: evaluacion.dietQuality,
      selfEfficacy: evaluacion.selfEfficacy,
      peerRelationship: evaluacion.peerRelationship,
      financialStress: evaluacion.financialStress,
      sleepQuality: evaluacion.sleepQuality,
      resultado: evaluacion.resultado != null
          ? ResultadoMlModel.fromEntity(evaluacion.resultado!)
          : null,
    );
  }

  /// Convierte el DTO a JSON (para enviar a la API)
  Map<String, dynamic> toJson() {
    return {
      'id_evaluacion': idEvaluacion,
      'id_usuario': idUsuario,
      'fecha_realizacion': fechaRealizacion,
      'phq9_score': phq9Score,
      'gad7_score': gad7Score,
      'sleep_hours': sleepHours,
      'exercise_freq': exerciseFreq,
      'social_activity': socialActivity,
      'online_stress': onlineStress,
      'gpa': gpa,
      'family_support': familySupport,
      'screen_time': screenTime,
      'academic_stress': academicStress,
      'diet_quality': dietQuality,
      'self_efficacy': selfEfficacy,
      'peer_relationship': peerRelationship,
      'financial_stress': financialStress,
      'sleep_quality': sleepQuality,
    };
  }
}

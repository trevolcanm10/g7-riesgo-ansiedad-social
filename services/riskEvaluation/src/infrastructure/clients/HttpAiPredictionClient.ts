import {
  AiPredictionClient,
  AiPredictionInput,
  AiPredictionResult,
} from "../../application/clients/AiPredictionClient.js";
import { AI_PREDICTION_URL } from "../../config/config.js";
import { AIReport, RiskLevel } from "../../domain/entities/RiskEvaluation.js";

interface PythonAIReport {
  resumen: string;
  fortalezas: string[];
  factores_preocupantes: string[];
  recomendaciones: string[];
  plan_7_dias: string[];
  temas_videos: string[];
  temas_lectura: string[];
  prioridad_intervencion: string;
  mensaje_motivacional: string;
  error?: string;
}

interface PythonPredictionResponse {
  probabilidad_ansiedad: number;
  nivel_riesgo: RiskLevel;
  explicacion: string;
  reporte_ia: PythonAIReport;
}

interface PythonErrorResponse {
  mensaje?: string;
  error?: string;
}

export class HttpAiPredictionClient implements AiPredictionClient {
  private readonly predictionUrl: string =
    AI_PREDICTION_URL ?? "http://localhost:3003";

  async predict(input: AiPredictionInput): Promise<AiPredictionResult> {
    const response = await fetch(`${this.predictionUrl}/predict`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        phq9_score: input.phq9Score,
        gad7_score: input.gad7Score,
        sleep_hours: input.sleepHours,
        exercise_freq: input.exerciseFreq,
        social_activity: input.socialActivity,
        online_stress: input.onlineStress,
        gpa: input.gpa,
        family_support: input.familySupport,
        screen_time: input.screenTime,
        academic_stress: input.academicStress,
        diet_quality: input.dietQuality,
        self_efficacy: input.selfEfficacy,
        peer_relationship: input.peerRelationship,
        financial_stress: input.financialStress,
        sleep_quality: input.sleepQuality,
      }),
    });

    if (!response.ok) {
      const errorData = (await response
        .json()
        .catch(() => ({}))) as PythonErrorResponse;

      throw new Error(
        errorData.mensaje ??
          errorData.error ??
          `El servicio de IA respondió con HTTP ${response.status}`,
      );
    }

    const data = (await response.json()) as PythonPredictionResponse;

    return {
      anxietyProbability: data.probabilidad_ansiedad,
      riskLevel: data.nivel_riesgo,
      explanation: data.explicacion,
      aiReport: this.mapAIReport(data.reporte_ia),
    };
  }

  private mapAIReport(report: PythonAIReport): AIReport {
    return {
      summary: report.resumen,
      strengths: report.fortalezas,
      concerningFactors: report.factores_preocupantes,
      recommendations: report.recomendaciones,
      sevenDayPlan: report.plan_7_dias,
      videoTopics: report.temas_videos,
      readingTopics: report.temas_lectura,
      priorityIntervention: report.prioridad_intervencion,
      motivationalMessage: report.mensaje_motivacional,
      ...(report.error !== undefined ? { error: report.error } : {}),
    };
  }
}

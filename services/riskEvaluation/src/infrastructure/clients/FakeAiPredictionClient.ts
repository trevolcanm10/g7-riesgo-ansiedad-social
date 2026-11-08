import {
  AiPredictionClient,
  AiPredictionInput,
  AiPredictionResult,
} from "../../application/clients/AiPredictionClient.js";

export class FakeAiPredictionClient implements AiPredictionClient {
  async predict(_input: AiPredictionInput): Promise<AiPredictionResult> {
    return {
      anxietyProbability: 0.42,
      riskLevel: "MEDIO",
      explanation:
        "Se detectan ciertos niveles de alerta en los indicadores evaluados.",
      aiReport: {
        summary:
          "La evaluación simulada identifica algunos factores que conviene atender.",
        strengths: [
          "Cuenta con factores de apoyo personal.",
          "Puede desarrollar hábitos saludables.",
        ],
        concerningFactors: [
          "Se identifican indicadores que requieren seguimiento.",
          "Conviene prestar atención al estrés académico.",
        ],
        recommendations: [
          "Organizar horarios de estudio y descanso.",
          "Incorporar pausas durante las actividades académicas.",
          "Considerar acudir al servicio de bienestar universitario.",
        ],
        sevenDayPlan: [
          "Día 1: organizar las actividades académicas.",
          "Día 2: establecer un horario de sueño regular.",
          "Día 3: realizar una actividad física.",
          "Día 4: practicar una técnica de relajación.",
          "Día 5: conversar con una persona de confianza.",
          "Día 6: revisar los avances de la semana.",
          "Día 7: evaluar los hábitos y planificar la siguiente semana.",
        ],
        videoTopics: ["Manejo del estrés académico", "Técnicas de relajación"],
        readingTopics: [
          "Hábitos de sueño saludables",
          "Organización del tiempo de estudio",
        ],
        priorityIntervention: "SEGUIMIENTO",
        motivationalMessage:
          "Pequeños pasos constantes pueden ayudarte a cuidar tu bienestar.",
      },
    };
  }
}

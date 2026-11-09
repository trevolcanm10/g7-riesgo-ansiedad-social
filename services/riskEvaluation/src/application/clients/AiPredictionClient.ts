import { AIReport, RiskLevel } from "../../domain/entities/RiskEvaluation.js";

export interface AiPredictionInput {
  phq9Score: number;
  gad7Score: number;
  sleepHours: number;
  exerciseFreq: number;
  socialActivity: number;
  onlineStress: number;
  gpa: number;
  familySupport: number;
  screenTime: number;
  academicStress: number;
  dietQuality: number;
  selfEfficacy: number;
  peerRelationship: number;
  financialStress: number;
  sleepQuality: number;
}

export interface AiPredictionResult {
  anxietyProbability: number;
  riskLevel: RiskLevel;
  explanation: string;
  aiReport: AIReport;
}

export interface AiPredictionClient {
  predict(input: AiPredictionInput): Promise<AiPredictionResult>;
}

import { RiskEvaluation } from "../../domain/entities/RiskEvaluation.js";
import { RiskEvaluationRepository } from "../../domain/repositories/RiskEvaluationRepository.js";
import { RiskRecommendationRepository } from "../../domain/repositories/RiskRecommendationRepository.js";
import {
  AiPredictionClient,
  AiPredictionInput,
} from "../clients/AiPredictionClient.js";
import { RecommendationNotFoundError } from "../errors/RecommendationNotFoundError.js";

export interface CreateRiskEvaluationInput extends AiPredictionInput {
  userId: number;
}

export class CreateRiskEvaluation {
  private readonly riskEvaluationRepository: RiskEvaluationRepository;
  private readonly riskRecommendationRepository: RiskRecommendationRepository;
  private readonly aiPredictionClient: AiPredictionClient;

  constructor(
    riskEvaluationRepository: RiskEvaluationRepository,
    riskRecommendationRepository: RiskRecommendationRepository,
    aiPredictionClient: AiPredictionClient,
  ) {
    this.riskEvaluationRepository = riskEvaluationRepository;
    this.riskRecommendationRepository = riskRecommendationRepository;
    this.aiPredictionClient = aiPredictionClient;
  }

  async execute(input: CreateRiskEvaluationInput): Promise<RiskEvaluation> {
    const prediction = await this.aiPredictionClient.predict({
      phq9Score: input.phq9Score,
      gad7Score: input.gad7Score,
      sleepHours: input.sleepHours,
      exerciseFreq: input.exerciseFreq,
      socialActivity: input.socialActivity,
      onlineStress: input.onlineStress,
      gpa: input.gpa,
      familySupport: input.familySupport,
      screenTime: input.screenTime,
      academicStress: input.academicStress,
      dietQuality: input.dietQuality,
      selfEfficacy: input.selfEfficacy,
      peerRelationship: input.peerRelationship,
      financialStress: input.financialStress,
      sleepQuality: input.sleepQuality,
    });

    const recommendation =
      await this.riskRecommendationRepository.findByCategory(
        prediction.riskLevel,
      );

    if (!recommendation) {
      throw new RecommendationNotFoundError(prediction.riskLevel);
    }

    const riskEvaluation = new RiskEvaluation({
      userId: input.userId,
      phq9Score: input.phq9Score,
      gad7Score: input.gad7Score,
      sleepHours: input.sleepHours,
      exerciseFreq: input.exerciseFreq,
      socialActivity: input.socialActivity,
      onlineStress: input.onlineStress,
      gpa: input.gpa,
      familySupport: input.familySupport,
      screenTime: input.screenTime,
      academicStress: input.academicStress,
      dietQuality: input.dietQuality,
      selfEfficacy: input.selfEfficacy,
      peerRelationship: input.peerRelationship,
      financialStress: input.financialStress,
      sleepQuality: input.sleepQuality,
      anxietyProbability: prediction.anxietyProbability,
      riskLevel: prediction.riskLevel,
      explanation: prediction.explanation,
      recommendations: [recommendation],
      aiReport: prediction.aiReport,
      createdAt: new Date(),
    });

    return this.riskEvaluationRepository.save(riskEvaluation);
  }
}

import { RiskEvaluation } from "../../domain/entities/RiskEvaluation.js";
import { RiskEvaluationRepository } from "../../domain/repositories/RiskEvaluationRepository.js";

export interface RiskEvaluationSummary {
  userId: number;
  anxietyProbability: number;
  riskLevel: string;
  createdAt: Date;
}

export class GetRiskEvaluationSummary {
  private readonly riskEvaluationRepository: RiskEvaluationRepository;

  constructor(riskEvaluationRepository: RiskEvaluationRepository) {
    this.riskEvaluationRepository = riskEvaluationRepository;
  }

  async execute(userIds: number[]): Promise<RiskEvaluationSummary[]> {
    const evaluations = await this.riskEvaluationRepository.findLatestByUserIds(
      userIds,
    );

    // Se expone solo lo necesario para correlacionar: identificador de
    // usuario, nivel de riesgo, probabilidad y fecha. No se incluye el
    // reporte de IA ni las explicaciones clinicas.
    return evaluations.map((evaluation) => ({
      userId: evaluation.getUserId(),
      anxietyProbability: evaluation.getAnxietyProbability(),
      riskLevel: evaluation.getRiskLevel(),
      createdAt: evaluation.getCreatedAt(),
    }));
  }
}

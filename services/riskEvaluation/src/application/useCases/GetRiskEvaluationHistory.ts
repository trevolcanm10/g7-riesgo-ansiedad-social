import { RiskEvaluation } from "../../domain/entities/RiskEvaluation.js";
import { RiskEvaluationRepository } from "../../domain/repositories/RiskEvaluationRepository.js";

export class GetRiskEvaluationHistory {
  private readonly riskEvaluationRepository: RiskEvaluationRepository;

  constructor(riskEvaluationRepository: RiskEvaluationRepository) {
    this.riskEvaluationRepository = riskEvaluationRepository;
  }

  execute(userId: number): Promise<RiskEvaluation[]> {
    return this.riskEvaluationRepository.findByUserId(userId);
  }
}

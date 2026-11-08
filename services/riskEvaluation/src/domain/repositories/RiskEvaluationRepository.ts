import { RiskEvaluation } from "../entities/RiskEvaluation.js";

export interface RiskEvaluationRepository {
  save(riskEvaluation: RiskEvaluation): Promise<RiskEvaluation>;
  findById(id: number): Promise<RiskEvaluation | null>;
  findByUserId(userId: number): Promise<RiskEvaluation[]>;
}

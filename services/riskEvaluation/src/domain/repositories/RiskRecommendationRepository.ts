import { RiskLevel, RiskRecommendation } from "../entities/RiskEvaluation.js";

export interface RiskRecommendationRepository {
  findByCategory(category: RiskLevel): Promise<RiskRecommendation | null>;
}

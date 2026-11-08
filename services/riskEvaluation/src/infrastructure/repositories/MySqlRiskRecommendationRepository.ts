import { RowDataPacket } from "mysql2";
import { pool } from "../../config/database.js";
import {
  RiskLevel,
  RiskRecommendation,
} from "../../domain/entities/RiskEvaluation.js";
import { RiskRecommendationRepository } from "../../domain/repositories/RiskRecommendationRepository.js";

interface RiskRecommendationRow extends RowDataPacket {
  id: number;
  category: RiskLevel;
  title: string;
  description: string;
}

export class MySqlRiskRecommendationRepository implements RiskRecommendationRepository {
  async findByCategory(
    category: RiskLevel,
  ): Promise<RiskRecommendation | null> {
    const [rows] = await pool.execute<RiskRecommendationRow[]>(
      `
        SELECT
          id,
          category,
          title,
          description
        FROM risk_recommendations
        WHERE category = ?
      `,
      [category],
    );

    if (rows.length === 0) {
      return null;
    }

    const row = rows[0];

    return {
      id: row.id,
      category: row.category,
      title: row.title,
      description: row.description,
    };
  }
}

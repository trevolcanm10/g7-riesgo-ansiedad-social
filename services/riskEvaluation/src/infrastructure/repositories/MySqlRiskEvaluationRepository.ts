import { pool } from "../../config/database.js";
import {
  AIReport,
  RiskEvaluation,
  RiskLevel,
  RiskRecommendation,
} from "../../domain/entities/RiskEvaluation.js";
import { RiskEvaluationRepository } from "../../domain/repositories/RiskEvaluationRepository.js";
import { ResultSetHeader, RowDataPacket } from "mysql2";

interface RiskEvaluationRow extends RowDataPacket {
  id: number;
  user_id: number;
  risk_recommendation_id: number;

  phq9_score: number;
  gad7_score: number;
  sleep_hours: number;
  exercise_freq: number;
  social_activity: number;
  online_stress: number;
  gpa: number;
  family_support: number;
  screen_time: number;
  academic_stress: number;
  diet_quality: number;
  self_efficacy: number;
  peer_relationship: number;
  financial_stress: number;
  sleep_quality: number;

  anxiety_probability: number;
  risk_level: RiskLevel;
  explanation: string;
  ai_report: AIReport | string;
  created_at: Date;

  recommendation_id: number;
  recommendation_category: RiskLevel;
  recommendation_title: string;
  recommendation_description: string;
}

export class MySqlRiskEvaluationRepository implements RiskEvaluationRepository {
  async save(riskEvaluation: RiskEvaluation): Promise<RiskEvaluation> {
    const recommendation = riskEvaluation.getRecommendations()[0];

    const [result] = await pool.execute<ResultSetHeader>(
      `
        INSERT INTO risk_evaluations (
          user_id,
          risk_recommendation_id,
          phq9_score,
          gad7_score,
          sleep_hours,
          exercise_freq,
          social_activity,
          online_stress,
          gpa,
          family_support,
          screen_time,
          academic_stress,
          diet_quality,
          self_efficacy,
          peer_relationship,
          financial_stress,
          sleep_quality,
          anxiety_probability,
          risk_level,
          explanation,
          ai_report,
          created_at
        ) VALUES (
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
          ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
        )
      `,
      [
        riskEvaluation.getUserId(),
        recommendation.id,
        riskEvaluation.getPhq9Score(),
        riskEvaluation.getGad7Score(),
        riskEvaluation.getSleepHours(),
        riskEvaluation.getExerciseFreq(),
        riskEvaluation.getSocialActivity(),
        riskEvaluation.getOnlineStress(),
        riskEvaluation.getGpa(),
        riskEvaluation.getFamilySupport(),
        riskEvaluation.getScreenTime(),
        riskEvaluation.getAcademicStress(),
        riskEvaluation.getDietQuality(),
        riskEvaluation.getSelfEfficacy(),
        riskEvaluation.getPeerRelationship(),
        riskEvaluation.getFinancialStress(),
        riskEvaluation.getSleepQuality(),
        riskEvaluation.getAnxietyProbability(),
        riskEvaluation.getRiskLevel(),
        riskEvaluation.getExplanation(),
        JSON.stringify(riskEvaluation.getAiReport()),
        riskEvaluation.getCreatedAt(),
      ],
    );

    riskEvaluation.assignId(result.insertId);

    return riskEvaluation;
  }

  async findById(id: number): Promise<RiskEvaluation | null> {
    const [rows] = await pool.execute<RiskEvaluationRow[]>(
      `
        ${this.selectQuery()}
        WHERE e.id = ?
      `,
      [id],
    );

    if (rows.length === 0) {
      return null;
    }

    return this.toDomain(rows[0]);
  }

  async findByUserId(userId: number): Promise<RiskEvaluation[]> {
    const [rows] = await pool.execute<RiskEvaluationRow[]>(
      `
        ${this.selectQuery()}
        WHERE e.user_id = ?
        ORDER BY e.created_at DESC
      `,
      [userId],
    );

    return rows.map((row) => this.toDomain(row));
  }

  private selectQuery(): string {
    return `
      SELECT
        e.*,
        r.id AS recommendation_id,
        r.category AS recommendation_category,
        r.title AS recommendation_title,
        r.description AS recommendation_description
      FROM risk_evaluations e
      INNER JOIN risk_recommendations r
      ON r.id = e.risk_recommendation_id
    `;
  }

  private toDomain(row: RiskEvaluationRow): RiskEvaluation {
    const recommendation: RiskRecommendation = {
      id: row.recommendation_id,
      category: row.recommendation_category,
      title: row.recommendation_title,
      description: row.recommendation_description,
    };

    const aiReport =
      typeof row.ai_report === "string"
        ? (JSON.parse(row.ai_report) as AIReport)
        : row.ai_report;

    return new RiskEvaluation({
      id: row.id,
      userId: row.user_id,
      phq9Score: row.phq9_score,
      gad7Score: row.gad7_score,
      sleepHours: row.sleep_hours,
      exerciseFreq: row.exercise_freq,
      socialActivity: row.social_activity,
      onlineStress: row.online_stress,
      gpa: row.gpa,
      familySupport: row.family_support,
      screenTime: row.screen_time,
      academicStress: row.academic_stress,
      dietQuality: row.diet_quality,
      selfEfficacy: row.self_efficacy,
      peerRelationship: row.peer_relationship,
      financialStress: row.financial_stress,
      sleepQuality: row.sleep_quality,
      anxietyProbability: row.anxiety_probability,
      riskLevel: row.risk_level,
      explanation: row.explanation,
      recommendations: [recommendation],
      aiReport,
      createdAt: row.created_at,
    });
  }
}

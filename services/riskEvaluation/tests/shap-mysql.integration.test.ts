import assert from "node:assert/strict";
import { test } from "node:test";
import { pool } from "../src/config/database.js";
import { RiskEvaluation } from "../src/domain/entities/RiskEvaluation.js";
import { MySqlRiskEvaluationRepository } from "../src/infrastructure/repositories/MySqlRiskEvaluationRepository.js";

test("local MySQL stores and reads SHAP without retaining test data", {
  skip: process.env.RUN_MYSQL_SHAP_INTEGRATION !== "1",
}, async () => {
  const connection = await pool.getConnection();
  const originalExecute = pool.execute;
  try {
    await connection.beginTransaction();
    pool.execute = ((sql: string, values: unknown[]) =>
      connection.execute(sql, values)) as typeof pool.execute;
    const [recommendations] = await connection.query(
      "SELECT id, category, title, description FROM risk_recommendations LIMIT 1",
    );
    const recommendation = (recommendations as Array<{
      id: number; category: "BAJO" | "MEDIO" | "ALTO";
      title: string; description: string;
    }>)[0];
    assert.ok(recommendation);
    const shap = {
      estado: "disponible" as const,
      escala: "log_odds_riesgo_clase_0" as const,
      factores: [{ nombre: "prueba", valor: 0.2, direccion: "aumenta" as const }],
    };
    const evaluation = new RiskEvaluation({
      userId: 999999999999, phq9Score: 1, gad7Score: 1, sleepHours: 7,
      exerciseFreq: 2, socialActivity: 2, onlineStress: 2, gpa: 3,
      familySupport: 5, screenTime: 5, academicStress: 5,
      dietQuality: 5, selfEfficacy: 5, peerRelationship: 5,
      financialStress: 5, sleepQuality: 5, anxietyProbability: 0.2,
      riskLevel: recommendation.category, explanation: "Prueba temporal",
      recommendations: [recommendation],
      aiReport: {
        summary: "Prueba", strengths: [], concerningFactors: [],
        recommendations: [], sevenDayPlan: [], videoTopics: [], readingTopics: [],
        priorityIntervention: "SEGUIMIENTO", motivationalMessage: "Prueba",
      },
      shapExplanation: shap,
      createdAt: new Date(),
    });
    const repository = new MySqlRiskEvaluationRepository();
    await repository.save(evaluation);
    const loaded = await repository.findById(evaluation.getId()!);
    const history = await repository.findByUserId(evaluation.getUserId());
    assert.deepEqual(loaded?.getShapExplanation(), shap);
    assert.deepEqual(history[0].getShapExplanation(), shap);
  } finally {
    pool.execute = originalExecute;
    await connection.rollback();
    connection.release();
    await pool.end();
  }
});

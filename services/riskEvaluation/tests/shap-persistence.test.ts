import assert from "node:assert/strict";
import { afterEach, test } from "node:test";
import { pool } from "../src/config/database.js";
import { RiskEvaluation } from "../src/domain/entities/RiskEvaluation.js";
import { MySqlRiskEvaluationRepository } from "../src/infrastructure/repositories/MySqlRiskEvaluationRepository.js";
import { MySqlRiskRecommendationRepository } from "../src/infrastructure/repositories/MySqlRiskRecommendationRepository.js";
import { RiskEvaluationController } from "../src/presentation/controllers/RiskEvaluationController.js";
import { GetRiskEvaluationHistory } from "../src/application/useCases/GetRiskEvaluationHistory.js";

const originalExecute = pool.execute;
afterEach(() => { pool.execute = originalExecute; });

const shap = {
  estado: "disponible" as const,
  escala: "log_odds_riesgo_clase_0" as const,
  factores: [{ nombre: "estrés académico", valor: 0.4, direccion: "aumenta" as const }],
};
const recommendation = {
  id: 1, category: "MEDIO" as const, title: "Apoyo", description: "Atención y hábitos",
};

function evaluation(shapExplanation = shap) {
  return new RiskEvaluation({
    userId: 42, phq9Score: 8, gad7Score: 7, sleepHours: 7,
    exerciseFreq: 3, socialActivity: 5, onlineStress: 4, gpa: 3.8,
    familySupport: 7, screenTime: 6, academicStress: 5,
    dietQuality: 7, selfEfficacy: 6, peerRelationship: 7,
    financialStress: 3, sleepQuality: 6, anxietyProbability: 0.42,
    riskLevel: "MEDIO", explanation: "Evaluación", recommendations: [recommendation],
    aiReport: { summary: "Resumen", strengths: [], concerningFactors: [], recommendations: [],
      sevenDayPlan: [], videoTopics: [], readingTopics: [], priorityIntervention: "SEGUIMIENTO",
      motivationalMessage: "Ánimo" },
    shapExplanation, createdAt: new Date("2026-11-13T12:00:00Z"),
  });
}

function row(shapValue: unknown) {
  return {
    id: 9, user_id: 42, risk_recommendation_id: 1,
    phq9_score: 8, gad7_score: 7, sleep_hours: 7, exercise_freq: 3,
    social_activity: 5, online_stress: 4, gpa: 3.8, family_support: 7,
    screen_time: 6, academic_stress: 5, diet_quality: 7, self_efficacy: 6,
    peer_relationship: 7, financial_stress: 3, sleep_quality: 6,
    anxiety_probability: 0.42, risk_level: "MEDIO", explanation: "Evaluación",
    ai_report: { summary: "Resumen" }, shap_explanation: shapValue,
    created_at: new Date("2026-11-13T12:00:00Z"),
    recommendation_id: 1, recommendation_category: "MEDIO",
    recommendation_title: "Apoyo", recommendation_description: "Atención y hábitos",
  };
}

test("save persists SHAP as nullable JSON alongside the evaluation", async () => {
  let sql = "";
  let values: unknown[] = [];
  pool.execute = (async (query: string, parameters: unknown[]) => {
    sql = query; values = parameters;
    return [{ insertId: 9 }, []];
  }) as typeof pool.execute;
  const saved = await new MySqlRiskEvaluationRepository().save(evaluation());
  assert.equal(saved.getId(), 9);
  assert.match(sql, /shap_explanation/);
  assert.equal(values.length, 23);
  assert.deepEqual(JSON.parse(values[21] as string), shap);
  assert.equal(values[22] instanceof Date, true);
});

test("reads SHAP from MySQL string or object and preserves old NULL rows", async () => {
  const repository = new MySqlRiskEvaluationRepository();
  for (const value of [JSON.stringify(shap), shap, null]) {
    pool.execute = (async () => [[row(value)], []]) as typeof pool.execute;
    const found = await repository.findById(9);
    assert.deepEqual(found?.getShapExplanation(), value === null ? undefined : shap);
  }
});

test("history returns SHAP and explicit null for old evaluations", async () => {
  pool.execute = (async () => [[row(shap), row(null)], []]) as typeof pool.execute;
  const controller = new RiskEvaluationController(
    {} as never,
    new GetRiskEvaluationHistory(new MySqlRiskEvaluationRepository()),
  );
  let response: unknown;
  await controller.getMyHistory(
    { userId: 42 } as never,
    { status: () => ({ json: (body: unknown) => { response = body; } }) } as never,
  );
  const items = response as Array<{ shapExplanation: unknown }>;
  assert.deepEqual(items[0].shapExplanation, shap);
  assert.equal(items[1].shapExplanation, null);
});

test("legacy recommendation mojibake is decoded only on read", async () => {
  pool.execute = (async () => [[{
    id: 1, category: "MEDIO", title: "Apoyo",
    description: "Atenci\u00c3\u00b3n y h\u00c3\u00a1bitos",
  }], []]) as typeof pool.execute;
  const found = await new MySqlRiskRecommendationRepository().findByCategory("MEDIO");
  assert.equal(found?.description, "Atención y hábitos");
});

test("history JOIN decodes legacy recommendation text without changing SHAP", async () => {
  pool.execute = (async () => [[{
    ...row(shap),
    recommendation_description: "Atenci\u00c3\u00b3n y h\u00c3\u00a1bitos",
  }], []]) as typeof pool.execute;
  const found = await new MySqlRiskEvaluationRepository().findById(9);
  assert.equal(found?.getRecommendations()[0].description, "Atención y hábitos");
  assert.deepEqual(found?.getShapExplanation(), shap);
});

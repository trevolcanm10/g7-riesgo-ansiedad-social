import { Request, Response } from "express";
import { CreateRiskEvaluation } from "../../application/useCases/CreateRiskEvaluation.js";
import { GetRiskEvaluationHistory } from "../../application/useCases/GetRiskEvaluationHistory.js";
import { createRiskEvaluationSchema } from "../dtos/CreateRiskEvaluationDTO.js";

export class RiskEvaluationController {
  private readonly createRiskEvaluation: CreateRiskEvaluation;
  private readonly getRiskEvaluationHistory: GetRiskEvaluationHistory;

  constructor(
    createRiskEvaluation: CreateRiskEvaluation,
    getRiskEvaluationHistory: GetRiskEvaluationHistory,
  ) {
    this.createRiskEvaluation = createRiskEvaluation;
    this.getRiskEvaluationHistory = getRiskEvaluationHistory;
  }

  async getMyHistory(req: Request, res: Response): Promise<void> {
    if (req.userId === undefined) {
      res.status(401).json({
        message: "Usuario no autenticado",
      });

      return;
    }

    const evaluations = await this.getRiskEvaluationHistory.execute(req.userId);

    res.status(200).json(
      evaluations.map((riskEvaluation) => ({
        id: riskEvaluation.getId(),
        userId: riskEvaluation.getUserId(),
        anxietyProbability: riskEvaluation.getAnxietyProbability(),
        riskLevel: riskEvaluation.getRiskLevel(),
        explanation: riskEvaluation.getExplanation(),
        recommendations: riskEvaluation.getRecommendations(),
        aiReport: riskEvaluation.getAiReport(),
        createdAt: riskEvaluation.getCreatedAt(),
      })),
    );
  }

  async create(req: Request, res: Response): Promise<void> {
    if (req.userId === undefined) {
      res.status(401).json({
        message: "Usuario no autenticado",
      });

      return;
    }

    const inputData = createRiskEvaluationSchema.parse(req.body);

    const riskEvaluation = await this.createRiskEvaluation.execute({
      ...inputData,
      userId: req.userId,
    });

    // Tal vez crear un DTO para la respuesta
    res.status(201).json({
      id: riskEvaluation.getId(),
      userId: riskEvaluation.getUserId(),
      anxietyProbability: riskEvaluation.getAnxietyProbability(),
      riskLevel: riskEvaluation.getRiskLevel(),
      explanation: riskEvaluation.getExplanation(),
      recommendations: riskEvaluation.getRecommendations(),
      aiReport: riskEvaluation.getAiReport(),
      createdAt: riskEvaluation.getCreatedAt(),
    });
  }
}

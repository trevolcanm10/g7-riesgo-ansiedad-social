import { Request, Response } from "express";
import { CreateRiskEvaluation } from "../../application/useCases/CreateRiskEvaluation.js";
import { GetRiskEvaluationHistory } from "../../application/useCases/GetRiskEvaluationHistory.js";
import { GetRiskEvaluationSummary } from "../../application/useCases/GetRiskEvaluationSummary.js";
import { createRiskEvaluationSchema } from "../dtos/CreateRiskEvaluationDTO.js";

export class RiskEvaluationController {
  private readonly createRiskEvaluation: CreateRiskEvaluation;
  private readonly getRiskEvaluationHistory: GetRiskEvaluationHistory;
  private readonly getRiskEvaluationSummary: GetRiskEvaluationSummary;

  constructor(
    createRiskEvaluation: CreateRiskEvaluation,
    getRiskEvaluationHistory: GetRiskEvaluationHistory,
    getRiskEvaluationSummary: GetRiskEvaluationSummary,
  ) {
    this.createRiskEvaluation = createRiskEvaluation;
    this.getRiskEvaluationHistory = getRiskEvaluationHistory;
    this.getRiskEvaluationSummary = getRiskEvaluationSummary;
  }

  async getSummary(req: Request, res: Response): Promise<void> {
    const bruto = String(req.query.userIds ?? "").trim();

    if (!bruto) {
      res.status(400).json({ message: "Debe indicar el parametro userIds" });

      return;
    }

    const userIds = bruto
      .split(",")
      .map((valor) => Number(valor.trim()))
      .filter((valor) => Number.isInteger(valor) && valor > 0);

    if (userIds.length === 0) {
      res.status(400).json({ message: "El parametro userIds no contiene identificadores validos" });

      return;
    }

    const resumen = await this.getRiskEvaluationSummary.execute(userIds);

    res.status(200).json(
      resumen.map((item) => ({
        userId: item.userId,
        anxietyProbability: item.anxietyProbability,
        riskLevel: item.riskLevel,
        createdAt: item.createdAt,
      })),
    );
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

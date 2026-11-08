import express from "express";
import { logger } from "./config/logger.js";
import { PORT } from "./config/config.js";
import { HttpAiPredictionClient } from "./infrastructure/clients/HttpAiPredictionClient.js";
import { MySqlRiskEvaluationRepository } from "./infrastructure/repositories/MySqlRiskEvaluationRepository.js";
import { MySqlRiskRecommendationRepository } from "./infrastructure/repositories/MySqlRiskRecommendationRepository.js";
import { JwtTokenService } from "./infrastructure/services/JwtTokenService.js";
import { CreateRiskEvaluation } from "./application/useCases/CreateRiskEvaluation.js";
import { GetRiskEvaluationHistory } from "./application/useCases/GetRiskEvaluationHistory.js";
import { RiskEvaluationController } from "./presentation/controllers/RiskEvaluationController.js";
import { createAuthMiddleware } from "./presentation/middlewares/authMiddleware.js";
import { createRiskEvaluationRouter } from "./presentation/routes/riskEvaluationRoutes.js";
import { errorHandler } from "./presentation/middlewares/errorHandler.js";
import { FakeAiPredictionClient } from "./infrastructure/clients/FakeAiPredictionClient.js";
import { pool } from "./config/database.js";
import { httpLoggingMiddleware } from "./presentation/middlewares/httpLogginMiddleware.js";

const app = express();

app.use(httpLoggingMiddleware);
app.use(express.json());

const aiPredictionClient = new HttpAiPredictionClient();
// const aiPredictionClient = new FakeAiPredictionClient();
const riskEvaluationRepository = new MySqlRiskEvaluationRepository();
const riskRecommendationRepository = new MySqlRiskRecommendationRepository();
const tokenService = new JwtTokenService();

const createRiskEvaluation = new CreateRiskEvaluation(
  riskEvaluationRepository,
  riskRecommendationRepository,
  aiPredictionClient,
);

const getRiskEvaluationHistory = new GetRiskEvaluationHistory(
  riskEvaluationRepository,
);

const riskEvaluationController = new RiskEvaluationController(
  createRiskEvaluation,
  getRiskEvaluationHistory,
);

const authMiddleware = createAuthMiddleware(tokenService);

const riskEvaluationRouter = createRiskEvaluationRouter(
  riskEvaluationController,
  authMiddleware,
);

app.use("/risk-evaluations", riskEvaluationRouter);

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");

    res.status(200).json({
      service: "riskEvaluation",
      status: "OK",
      database: "OK",
    });
  } catch (error) {
    console.error("ERROR MYSQL:", error);

    logger.error({ err: error }, "Error consultando MySQL en /health");

    res.status(503).json({
      service: "riskEvaluation",
      status: "ERROR",
      database: "UNAVAILABLE",
    });
  }
});

app.get("/test-error-500", (_req, res) => {
  res.status(500).json({
    success: false,
    message: "Error 500 de prueba para verificar las métricas",
  });
});

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Risk Evaluation Service corriendo en el puerto ${PORT}`);

  logger.info({ port: PORT }, "Risk Evaluation Service iniciado");
});

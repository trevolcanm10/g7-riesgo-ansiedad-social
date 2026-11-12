import { RequestHandler, Router } from "express";
import { RiskEvaluationController } from "../controllers/RiskEvaluationController.js";
import { createRoleMiddleware } from "../middlewares/roleMiddleware.js";

export const createRiskEvaluationRouter = (
  riskEvaluationController: RiskEvaluationController,
  authMiddleware: RequestHandler,
): Router => {
  const router = Router();

  router.get(
    "/summary",
    authMiddleware,
    createRoleMiddleware("PERSONAL_UNAYOE", "ADMINISTRADOR"),
    (req, res) => riskEvaluationController.getSummary(req, res),
  );

  router.get(
    "/me/history",
    authMiddleware,
    createRoleMiddleware("ESTUDIANTE", "ADMINISTRADOR"),
    (req, res) => riskEvaluationController.getMyHistory(req, res),
  );

  router.post(
    "/",
    authMiddleware,
    createRoleMiddleware("ESTUDIANTE", "ADMINISTRADOR"),
    (req, res) => riskEvaluationController.create(req, res),
  );

  return router;
};

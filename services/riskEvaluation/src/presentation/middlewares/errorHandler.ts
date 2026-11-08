import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { RecommendationNotFoundError } from "../../application/errors/RecommendationNotFoundError.js";

export const errorHandler = (
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  if (error instanceof ZodError) {
    res.status(400).json({
      message: "Los datos enviados no son válidos",
      errors: error.issues.map((issue) => ({
        field: issue.path.join("."),
        message: issue.message,
      })),
    });
    return;
  }

  if (error instanceof RecommendationNotFoundError) {
    res.status(500).json({
      message: error.message,
    });

    return;
  }

  console.error("Error no controlado: ", error);

  res.status(500).json({
    message: "Error interno del servidor",
  });
};

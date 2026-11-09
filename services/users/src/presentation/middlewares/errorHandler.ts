import { NextFunction, Request, Response } from "express";
import { ZodError } from "zod";
import { UserAlreadyExistsError } from "../../application/errors/UserAlreadyExistsError.js";
import { InvalidCredentialsError } from "../../application/errors/InvalidCredentialsError.js";
import { UserNotFoundError } from "../../application/errors/UserNotFoundError.js";

export const errorHandler = (
  error: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void => {
  if (error instanceof UserAlreadyExistsError) {
    res.status(409).json({
      message: error.message,
    });

    return;
  }

  if (error instanceof UserNotFoundError) {
    res.status(404).json({
      message: error.message,
    });

    return;
  }

  if (error instanceof InvalidCredentialsError) {
    res.status(401).json({
      message: error.message,
    });

    return;
  }

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

  console.log("Error no controlado: ", error);

  res.status(500).json({
    message: "Error interno del servidor",
  });
};

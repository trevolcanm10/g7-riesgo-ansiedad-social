import { NextFunction, Request, Response } from "express";
import { UserRole } from "../../application/services/TokenService.js";

export const createRoleMiddleware = (...allowedRoles: UserRole[]) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.userId || !req.userRole) {
      res.status(401).json({
        message: "Usuario no autenticado",
      });
      return;
    }

    if (!allowedRoles.includes(req.userRole)) {
      res.status(403).json({
        message: "No tienes permisos para realizar esta operación",
      });
      return;
    }

    next();
  };
};

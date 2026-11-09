import { NextFunction, Request, Response } from "express";
import { TokenService } from "../../application/services/TokenService.js";

export const createAuthMiddleware = (tokenService: TokenService) => {
  return (req: Request, res: Response, next: NextFunction): void => {
    const authorization = req.headers.authorization;

    if (!authorization) {
      res.status(401).json({
        message: "Token de autenticación requerido",
      });

      return;
    }

    const [type, token] = authorization.split(" ");

    if (type !== "Bearer" || !token) {
      res.status(401).json({
        message: "Formato de token inválido",
      });

      return;
    }

    try {
      const payload = tokenService.verifyAccessToken(token);

      req.userId = payload.userId;
      req.userRole = payload.role;

      next();
    } catch (error) {
      res.status(401).json({
        message: "Token inválido o expirado",
      });
    }
  };
};

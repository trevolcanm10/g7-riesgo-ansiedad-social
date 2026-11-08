import {
  AccessTokenPayload,
  TokenService,
  UserRole,
} from "../../application/services/TokenService.js";
import { JWT_SECRET } from "../../config/config.js";
import jwt from "jsonwebtoken";

const USER_ROLES: readonly UserRole[] = [
  "ESTUDIANTE",
  "PERSONAL_UNAYOE",
  "ADMINISTRADOR",
];

export class JwtTokenService implements TokenService {
  verifyAccessToken(token: string): AccessTokenPayload {
    if (!JWT_SECRET) {
      throw new Error("JWT_SECRET no está configurado");
    }

    const payload = jwt.verify(token, JWT_SECRET);

    if (
      typeof payload !== "object" ||
      payload === null ||
      typeof payload.userId !== "number" ||
      !Number.isInteger(payload.userId) ||
      payload.userId <= 0 ||
      typeof payload.role !== "string" ||
      !USER_ROLES.includes(payload.role as UserRole)
    ) {
      throw new Error("Token inválido");
    }

    return {
      userId: payload.userId,
      role: payload.role as UserRole,
    };
  }
}

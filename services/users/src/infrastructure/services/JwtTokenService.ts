import jwt from "jsonwebtoken";
import {
  AccessTokenPayload,
  TokenService,
} from "../../application/services/TokenService.js";
import { JWT_SECRET } from "../../config/config.js";
import { UserRole } from "../../domain/entities/User.js";

const USER_ROLES: readonly UserRole[] = [
  "ESTUDIANTE",
  "PERSONAL_UNAYOE",
  "ADMINISTRADOR",
];

export class JwtTokenServices implements TokenService {
  generateAccessToken(userId: number, role: UserRole): string {
    if (!JWT_SECRET) {
      throw new Error("JWT_SECRET no está configurado");
    }

    if (!Number.isInteger(userId) || userId <= 0) {
      throw new Error("El ID del usuario no es válido");
    }

    if (!USER_ROLES.includes(role)) {
      throw new Error("El rol del usuario no es válido");
    }

    return jwt.sign(
      {
        userId,
        role,
      },
      JWT_SECRET,
      {
        expiresIn: "1h",
      },
    );
  }

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

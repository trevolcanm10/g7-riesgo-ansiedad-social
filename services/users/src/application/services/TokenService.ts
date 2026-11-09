import { UserRole } from "../../domain/entities/User.js";

export interface AccessTokenPayload {
  userId: number;
  role: UserRole;
}

export interface TokenService {
  generateAccessToken(userId: number, role: UserRole): string;
  verifyAccessToken(token: string): AccessTokenPayload;
}

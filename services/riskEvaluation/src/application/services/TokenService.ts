export type UserRole = "ESTUDIANTE" | "PERSONAL_UNAYOE" | "ADMINISTRADOR";

export interface AccessTokenPayload {
  userId: number;
  role: UserRole;
}

export interface TokenService {
  verifyAccessToken(token: string): AccessTokenPayload;
}

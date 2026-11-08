import type { UserRole } from "../../domain/entities/User.ts";

declare global {
  namespace Express {
    interface Request {
      userId?: number;
      userRole?: UserRole;
    }
  }
}

export {};

import { UserRole } from "../../application/services/TokenService.ts";

declare global {
  namespace Express {
    interface Request {
      userId?: number;
      userRole?: UserRole;
    }
  }
}

export {};

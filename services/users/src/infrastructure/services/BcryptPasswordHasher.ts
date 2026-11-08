import bcrypt from "bcrypt";
import { PasswordHasher } from "../../application/services/PasswordHasher.js";

export class BcryptPasswordHasher implements PasswordHasher {
  private readonly saltRounds = 10;

  async hash(password: string): Promise<string> {
    return await bcrypt.hash(password, this.saltRounds);
  }

  async compare(password: string, hashedPassword: string): Promise<boolean> {
    return await bcrypt.compare(password, hashedPassword);
  }
}

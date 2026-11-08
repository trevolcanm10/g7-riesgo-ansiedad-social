import { User } from "../entities/User.js";

export interface UserUpdate {
  names?: string;
  surnames?: string;
  code?: string;
  school?: string;
  cycle?: number;
}

export interface UserRepository {
  save(user: User): Promise<User>;
  findById(id: number): Promise<User | null>;
  findByEmail(email: string): Promise<User | null>;
  findByCode(code: string): Promise<User | null>;
  findAll(): Promise<User[]>;
  update(id: number, input: UserUpdate): Promise<void>;
}

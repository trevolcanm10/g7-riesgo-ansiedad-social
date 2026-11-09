import { User } from "../../domain/entities/User.js";
import { UserRepository } from "../../domain/repositories/UserRepository.js";
import { UserAlreadyExistsError } from "../errors/UserAlreadyExistsError.js";
import { PasswordHasher } from "../services/PasswordHasher.js";

export interface CreateUserInput {
  names: string;
  surnames: string;
  code: string;
  email: string;
  password: string;
  school: string;
  cycle: number;
}

export class CreateUser {
  private readonly userRepository: UserRepository;
  private readonly passwordHasher: PasswordHasher;

  constructor(userRepository: UserRepository, passwordHasher: PasswordHasher) {
    this.userRepository = userRepository;
    this.passwordHasher = passwordHasher;
  }

  async execute(input: CreateUserInput): Promise<User> {
    const existingUserByEmail = await this.userRepository.findByEmail(
      input.email,
    );

    if (existingUserByEmail) {
      throw new UserAlreadyExistsError("El email ya está registrado");
    }

    const existingUserByCode = await this.userRepository.findByCode(input.code);

    if (existingUserByCode) {
      throw new UserAlreadyExistsError(
        "El código de estudiante ya está registrado",
      );
    }

    const hashedPassword = await this.passwordHasher.hash(input.password);

    const user = new User({
      names: input.names,
      surnames: input.surnames,
      code: input.code,
      email: input.email,
      password: hashedPassword,
      school: input.school,
      cycle: input.cycle,
      role: "ESTUDIANTE",
      createdAt: new Date(),
    });

    return await this.userRepository.save(user);
  }
}

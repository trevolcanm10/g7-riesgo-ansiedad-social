import { User } from "../../domain/entities/User.js";
import { UserRepository } from "../../domain/repositories/UserRepository.js";
import { InvalidCredentialsError } from "../errors/InvalidCredentialsError.js";
import { PasswordHasher } from "../services/PasswordHasher.js";
import { TokenService } from "../services/TokenService.js";

export interface LoginUserInput {
  email: string;
  password: string;
}

export interface LoginUserOuput {
  user: User;
  accessToken: string;
}

export class LoginUser {
  private readonly userRepository: UserRepository;
  private readonly passwordHasher: PasswordHasher;
  private readonly tokenService: TokenService;

  constructor(
    userRepository: UserRepository,
    passwordHasher: PasswordHasher,
    tokenService: TokenService,
  ) {
    this.userRepository = userRepository;
    this.passwordHasher = passwordHasher;
    this.tokenService = tokenService;
  }

  async execute(input: LoginUserInput): Promise<LoginUserOuput> {
    const user = await this.userRepository.findByEmail(input.email);

    if (!user) {
      throw new InvalidCredentialsError("El correo es inválido");
    }

    const passwordIsValid = await this.passwordHasher.compare(
      input.password,
      user.getPassword(),
    );

    if (!passwordIsValid) {
      throw new InvalidCredentialsError("La contraseña es inválida");
    }

    const userId = user.getId();

    const accessToken = this.tokenService.generateAccessToken(
      userId!,
      user.getRole(),
    );

    return {
      user,
      accessToken,
    };
  }
}

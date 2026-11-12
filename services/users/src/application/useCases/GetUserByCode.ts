import { User } from "../../domain/entities/User.js";
import { UserRepository } from "../../domain/repositories/UserRepository.js";
import { UserNotFoundError } from "../errors/UserNotFoundError.js";

export class GetUserByCode {
  private readonly userRepository: UserRepository;

  constructor(userRepository: UserRepository) {
    this.userRepository = userRepository;
  }

  async execute(code: string): Promise<User> {
    const user = await this.userRepository.findByCode(code);

    if (!user) {
      throw new UserNotFoundError();
    }

    return user;
  }
}

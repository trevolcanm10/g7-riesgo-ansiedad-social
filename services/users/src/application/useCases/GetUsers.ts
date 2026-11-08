import { User } from "../../domain/entities/User.js";
import { UserRepository } from "../../domain/repositories/UserRepository.js";

export class GetUsers {
  private readonly userRepository: UserRepository;

  constructor(userRepository: UserRepository) {
    this.userRepository = userRepository;
  }

  async execute(): Promise<User[]> {
    return await this.userRepository.findAll();
  }
}

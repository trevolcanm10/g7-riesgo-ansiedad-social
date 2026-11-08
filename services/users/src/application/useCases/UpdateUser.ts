import { User } from "../../domain/entities/User.js";
import {
  UserRepository,
  UserUpdate,
} from "../../domain/repositories/UserRepository.js";
import { UserAlreadyExistsError } from "../errors/UserAlreadyExistsError.js";
import { UserNotFoundError } from "../errors/UserNotFoundError.js";

export class UpdateUser {
  private readonly userRepository: UserRepository;

  constructor(userRepository: UserRepository) {
    this.userRepository = userRepository;
  }

  async execute(id: number, input: UserUpdate): Promise<User> {
    const user = await this.userRepository.findById(id);

    if (!user) {
      throw new UserNotFoundError();
    }

    if (input.code !== undefined && input.code !== user.getCode()) {
      const existingUser = await this.userRepository.findByCode(input.code);

      if (existingUser) {
        throw new UserAlreadyExistsError(
          "El código de estudiante ya está registrado",
        );
      }
    }

    await this.userRepository.update(id, input);
    const updatedUser = await this.userRepository.findById(id);

    if (!updatedUser) {
      throw new UserNotFoundError();
    }

    return updatedUser;
  }
}

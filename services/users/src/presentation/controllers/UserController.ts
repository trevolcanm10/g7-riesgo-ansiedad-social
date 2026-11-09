import { Request, Response } from "express";
import { CreateUser } from "../../application/useCases/CreateUser.js";
import { createUserSchema } from "../dtos/CreateUserDTO.js";
import { toUserResponseDTO } from "../dtos/UserResponseDTO.js";
import { GetUsers } from "../../application/useCases/GetUsers.js";
import { LoginUser } from "../../application/useCases/LoginUser.js";
import { loginUserSchema } from "../dtos/LoginUserDTO.js";
import { userIdParamsSchema } from "../dtos/UserIdParamsDTO.js";
import { GetUserById } from "../../application/useCases/GetUserById.js";
import { UpdateUser } from "../../application/useCases/UpdateUser.js";
import { updateUserSchema } from "../dtos/UpdateUserDTO.js";

export class UserController {
  private readonly getUsers: GetUsers;
  private readonly getUserById: GetUserById;
  private readonly createUser: CreateUser;
  private readonly loginUser: LoginUser;
  private readonly updateUser: UpdateUser;

  constructor(
    getUsers: GetUsers,
    getUserById: GetUserById,
    createUser: CreateUser,
    loginUser: LoginUser,
    updateUser: UpdateUser,
  ) {
    this.getUsers = getUsers;
    this.getUserById = getUserById;
    this.createUser = createUser;
    this.loginUser = loginUser;
    this.updateUser = updateUser;
  }

  async getAll(_req: Request, res: Response): Promise<void> {
    const users = await this.getUsers.execute();

    res.status(200).json(users.map((user) => toUserResponseDTO(user)));
  }

  async getById(req: Request, res: Response): Promise<void> {
    const { id } = userIdParamsSchema.parse(req.params);

    const user = await this.getUserById.execute(id);

    res.status(200).json(toUserResponseDTO(user));
  }

  async getMe(req: Request, res: Response): Promise<void> {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({
        message: "Usuario no autenticado",
      });

      return;
    }

    const user = await this.getUserById.execute(userId);

    res.status(200).json(toUserResponseDTO(user));
  }

  async create(req: Request, res: Response): Promise<void> {
    const input = createUserSchema.parse(req.body);

    const user = await this.createUser.execute(input);

    res.status(201).json(toUserResponseDTO(user));
  }

  async update(req: Request, res: Response): Promise<void> {
    const userId = req.userId;

    if (!userId) {
      res.status(401).json({
        message: "Usuario no autenticado",
      });

      return;
    }

    const input = updateUserSchema.parse(req.body);
    const user = await this.updateUser.execute(userId, input);

    res.status(200).json(toUserResponseDTO(user));
  }

  async login(req: Request, res: Response): Promise<void> {
    const input = loginUserSchema.parse(req.body);

    const { user, accessToken } = await this.loginUser.execute(input);

    res.status(200).json({
      message: "Inicio de sesión exitoso",
      user: toUserResponseDTO(user),
      accessToken,
    });
  }
}

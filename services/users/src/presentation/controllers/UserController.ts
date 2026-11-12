import { Request, Response } from "express";
import { CreateUser } from "../../application/useCases/CreateUser.js";
import { createUserSchema } from "../dtos/CreateUserDTO.js";
import { toUserResponseDTO } from "../dtos/UserResponseDTO.js";
import { GetUsers } from "../../application/useCases/GetUsers.js";
import { LoginUser } from "../../application/useCases/LoginUser.js";
import { loginUserSchema } from "../dtos/LoginUserDTO.js";
import { userIdParamsSchema } from "../dtos/UserIdParamsDTO.js";
import { GetUserById } from "../../application/useCases/GetUserById.js";
import { GetUserByCode } from "../../application/useCases/GetUserByCode.js";
import { UpdateUser } from "../../application/useCases/UpdateUser.js";
import { updateUserSchema } from "../dtos/UpdateUserDTO.js";
import { UserNotFoundError } from "../../application/errors/UserNotFoundError.js";

export class UserController {
  private readonly getUsers: GetUsers;
  private readonly getUserById: GetUserById;
  private readonly getUserByCode: GetUserByCode;
  private readonly createUser: CreateUser;
  private readonly loginUser: LoginUser;
  private readonly updateUser: UpdateUser;

  constructor(
    getUsers: GetUsers,
    getUserById: GetUserById,
    getUserByCode: GetUserByCode,
    createUser: CreateUser,
    loginUser: LoginUser,
    updateUser: UpdateUser,
  ) {
    this.getUsers = getUsers;
    this.getUserById = getUserById;
    this.getUserByCode = getUserByCode;
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

  async getByCode(req: Request, res: Response): Promise<void> {
    const codigo = String(req.params.code ?? "").trim();

    if (!codigo) {
      res.status(400).json({ message: "Debe indicar un codigo de estudiante" });

      return;
    }

    try {
      const user = await this.getUserByCode.execute(codigo);

      // Solo identificador y codigo: el consumidor es el panel institucional,
      // que no necesita ni debe recibir datos personales del estudiante.
      res.status(200).json({ id: user.getId(), code: user.getCode() });
    } catch (error) {
      if (error instanceof UserNotFoundError) {
        res.status(404).json({ message: "Usuario no encontrado" });

        return;
      }

      throw error;
    }
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

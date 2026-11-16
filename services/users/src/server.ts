import express from "express";
import { PORT } from "./config/config.js";
import { errorHandler } from "./presentation/middlewares/errorHandler.js";
import { MySqlUserRepository } from "./infrastructure/repositories/MySqlUserRepository.js";
import { CreateUser } from "./application/useCases/CreateUser.js";
import { BcryptPasswordHasher } from "./infrastructure/services/BcryptPasswordHasher.js";
import { UserController } from "./presentation/controllers/UserController.js";
import { createUserRouter } from "./presentation/routes/userRoutes.js";
import { pool } from "./config/database.js";
import { GetUsers } from "./application/useCases/GetUsers.js";
import { LoginUser } from "./application/useCases/LoginUser.js";
import { GetUserById } from "./application/useCases/GetUserById.js";
import { JwtTokenServices } from "./infrastructure/services/JwtTokenService.js";
import { createAuthMiddleware } from "./presentation/middlewares/authMiddleware.js";
import { UpdateUser } from "./application/useCases/UpdateUser.js";

const app = express();

app.use(express.json());

const userRepository = new MySqlUserRepository();
const passwordHasher = new BcryptPasswordHasher();
const tokenService = new JwtTokenServices();

const getUsers = new GetUsers(userRepository);
const getUserById = new GetUserById(userRepository);
const createUser = new CreateUser(userRepository, passwordHasher);
const loginUser = new LoginUser(userRepository, passwordHasher, tokenService);
const updateUser = new UpdateUser(userRepository);

const userController = new UserController(
  getUsers,
  getUserById,
  createUser,
  loginUser,
  updateUser,
);

const authMiddleware = createAuthMiddleware(tokenService);

const userRouter = createUserRouter(userController, authMiddleware);

app.use("/users", userRouter);

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");

    res.status(200).json({
      service: "users",
      status: "OK",
      database: "OK",
    });
  } catch (error) {
    console.error("ERROR MYSQL:", error);

    res.status(503).json({
      service: "users",
      status: "ERROR",
      database: "UNAVAILABLE",
    });
  }
});

app.use(errorHandler);

app.listen(PORT, () => {
  console.log(`Microservicio users ejecutándose en el puerto ${PORT}`);
});

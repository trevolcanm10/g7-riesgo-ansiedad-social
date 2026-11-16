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

// Middleware CORS solo para desarrollo local
app.use((req, res, next) => {
  const allowedOrigins = ["http://localhost:8082", "http://127.0.0.1:8082"];
  const origin = req.headers.origin as string | undefined;
  if (process.env.NODE_ENV === "development" && origin && allowedOrigins.includes(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Access-Control-Allow-Methods", "GET, HEAD, POST, PUT, DELETE, OPTIONS");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization");
    res.setHeader("Access-Control-Max-Age", "86400");
  }
  if (req.method === "OPTIONS" && process.env.NODE_ENV === "development" && origin && allowedOrigins.includes(origin)) {
    return res.sendStatus(204);
  }
  next();
});

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

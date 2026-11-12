import { RequestHandler, Router } from "express";
import { UserController } from "../controllers/UserController.js";
import { createRoleMiddleware } from "../middlewares/roleMiddleware.js";

export const createUserRouter = (
  userController: UserController,
  authMiddleware: RequestHandler,
) => {
  const router = Router();
  // Rutas públicas
  router.post("/", (req, res) => userController.create(req, res));
  router.post("/login", (req, res) => userController.login(req, res));

  // Rutas protegidas
  router.get("/me", authMiddleware, (req, res) =>
    userController.getMe(req, res),
  );
  router.get(
    "/",
    authMiddleware,
    createRoleMiddleware("PERSONAL_UNAYOE", "ADMINISTRADOR"),
    (req, res) => userController.getAll(req, res),
  );
  router.get(
    "/:id",
    authMiddleware,
    createRoleMiddleware("PERSONAL_UNAYOE", "ADMINISTRADOR"),
    (req, res) => userController.getById(req, res),
  );

  // Resuelve un codigo de estudiante a su identificador numerico.
  // Lo consume el Panel Institucional para correlacionar con las
  // evaluaciones de riesgo sin compartir bases de datos. Devuelve solo el
  // identificador y el codigo: no expone datos personales adicionales.
  router.get(
    "/by-code/:code",
    authMiddleware,
    createRoleMiddleware("PERSONAL_UNAYOE", "ADMINISTRADOR"),
    (req, res) => userController.getByCode(req, res),
  );
  router.patch(
    "/me",
    authMiddleware,
    createRoleMiddleware("ESTUDIANTE", "ADMINISTRADOR"),
    (req, res) => userController.update(req, res),
  );

  return router;
};

export class UserNotFoundError extends Error {
  constructor() {
    super("Usuario no encontrado");
    this.name = "UserNotFoundError";
  }
}

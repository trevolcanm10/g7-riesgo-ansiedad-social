import { z } from "zod";

export const loginUserSchema = z.object({
  email: z.string().trim().email("El correo no tiene un formato válido"),
  password: z.string().min(1, "La contraseña es obligatoria"),
});

export type LoginUserDTO = z.infer<typeof loginUserSchema>;

import { z } from "zod";

export const createUserSchema = z.object({
  names: z.string().trim().min(1, "Los nombres son obligatorios"),
  surnames: z.string().trim().min(1, "Los apellidos son obligatorios"),
  code: z.string().trim().min(1, "El código de estudiante es obligatorio"),
  email: z.string().trim().email("El correo no tiene un formato válido"),
  password: z.string().min(1, "La contraseña es obligatoria"),
  school: z.string().trim().min(1, "La escuela es obligatoria"),
  cycle: z.coerce
    .number()
    .int("El ciclo debe ser un número entero")
    .min(1, "El ciclo deber ser como mínimo 1")
    .max(12, "El ciclo debe ser como máximo 12"),
});

export type CreateUserDTO = z.infer<typeof createUserSchema>;

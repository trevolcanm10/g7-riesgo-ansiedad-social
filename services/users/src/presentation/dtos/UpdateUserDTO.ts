import { z } from "zod";

export const updateUserSchema = z
  .object({
    names: z.string().trim().min(1, "Valor no admitido").optional(),
    surnames: z.string().trim().min(1, "Valor no admitido").optional(),
    code: z.string().trim().min(1, "Valor no admitido").optional(),
    school: z.string().trim().min(1, "Valor no admitido").optional(),
    cycle: z.coerce
      .number()
      .int("El ciclo debe ser un número entero")
      .min(1, "El ciclo debe ser como mínimo 1")
      .max(12, "El ciclo debe ser como máximo 12")
      .optional(),
  })
  .strict()
  .refine((data) => Object.keys(data).length > 0, {
    message: "Debe enviar al menos un campo modificable",
  });

export type UpdateUserDTO = z.infer<typeof updateUserSchema>;

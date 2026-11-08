import { z } from "zod";

export const userIdParamsSchema = z.object({
  id: z.coerce.number().int().positive(),
});

export type UserIdParamsDTO = z.infer<typeof userIdParamsSchema>;

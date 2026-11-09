import { z } from "zod";

export const createRiskEvaluationSchema = z.object({
  phq9Score: z.number().int().min(0).max(27),
  gad7Score: z.number().int().min(0).max(21),
  sleepHours: z.number().int().min(3).max(10),
  exerciseFreq: z.number().int().min(0).max(7),
  socialActivity: z.number().int().min(0).max(10),
  onlineStress: z.number().int().min(1).max(10),
  gpa: z.number().min(0).max(5),
  familySupport: z.number().int().min(1).max(10),
  screenTime: z.number().int().min(1).max(12),
  academicStress: z.number().int().min(1).max(10),
  dietQuality: z.number().int().min(1).max(10),
  selfEfficacy: z.number().int().min(1).max(10),
  peerRelationship: z.number().int().min(1).max(10),
  financialStress: z.number().int().min(1).max(10),
  sleepQuality: z.number().int().min(0).max(10),
});

export type CreateRiskEvaluationDTO = z.infer<
  typeof createRiskEvaluationSchema
>;

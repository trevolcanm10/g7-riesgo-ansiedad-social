export class RecommendationNotFoundError extends Error {
  constructor(riskLevel: string) {
    super(
      `No se encontró una recomendación para el nivel de riesgo ${riskLevel}`,
    );

    this.name = "RecommendationNotFoundError";
  }
}

from typing import Mapping
import logging

from src.domain.risk import RiskPredictor, categorize_risk
from src.domain.report import ReportGenerator, EXPLANATIONS, validate_report


class PredictRiskUseCase:
    def __init__(self, predictor: RiskPredictor, report_generator: ReportGenerator):
        self.predictor = predictor
        self.report_generator = report_generator

    def execute(self, indicators: Mapping[str, float]) -> dict:
        probability = self.predictor.predict_probability(indicators)
        level = categorize_risk(probability)
        report = validate_report(self.report_generator.generate(dict(indicators), probability, level))
        explanation = {"estado": "no_disponible", "escala": "log_odds_riesgo_clase_0", "factores": []}
        try:
            explain = getattr(self.predictor, "explain_risk", None)
            if explain is not None:
                explanation = explain(indicators, probability)
        except Exception:
            logging.getLogger(__name__).warning("Explicación SHAP no disponible")
        return {
            "nivel_riesgo": level,
            "probabilidad_ansiedad": probability,
            "explicacion": EXPLANATIONS[level] + ' Esta estimación no es un diagnóstico clínico.',
            "reporte_ia": report,
            "explicacion_shap": explanation,
        }

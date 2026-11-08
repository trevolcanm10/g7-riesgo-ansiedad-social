from typing import Mapping

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
        return {
            "nivel_riesgo": level,
            "probabilidad_ansiedad": probability,
            "explicacion": EXPLANATIONS[level] + ' Esta estimación no es un diagnóstico clínico.',
            "reporte_ia": report,
        }

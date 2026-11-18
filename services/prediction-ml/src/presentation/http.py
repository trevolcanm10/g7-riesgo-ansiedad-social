from flask import Flask, jsonify, request
from werkzeug.exceptions import BadRequest, HTTPException

from src.application.predict_risk import PredictRiskUseCase
from src.domain.risk import ModelsUnavailableError, PredictionError
from src.presentation.validation import validate_indicators


def create_http_app(use_case: PredictRiskUseCase | None, models_loaded: int) -> Flask:
    app = Flask(__name__)

    @app.get("/health")
    def health():
        ready = use_case is not None and models_loaded == 5
        return jsonify(service="prediction-ml", status="OK" if ready else "UNAVAILABLE",
                       models_loaded=models_loaded), 200 if ready else 503

    @app.post("/predict")
    def predict():
        try:
            if not request.is_json:
                raise ValueError("Se requiere Content-Type: application/json")
            indicators = validate_indicators(request.get_json())
        except (ValueError, BadRequest) as exc:
            message = "JSON malformado" if isinstance(exc, BadRequest) else str(exc)
            return jsonify(error="Error", mensaje=message), 400
        if use_case is None:
            return jsonify(error="Error", mensaje="Los modelos no están disponibles"), 503
        try:
            return jsonify(use_case.execute(indicators))
        except ModelsUnavailableError:
            app.logger.error("Modelos no disponibles")
            return jsonify(error="Error", mensaje="Los modelos no están disponibles"), 503
        except PredictionError:
            app.logger.error("Error de inferencia")
            return jsonify(error="Error", mensaje="No se pudo realizar la predicción"), 500

    @app.errorhandler(Exception)
    def handle_error(exc):
        if isinstance(exc, HTTPException):
            return jsonify(error="Error", mensaje=exc.description), exc.code
        app.logger.error("Error interno")
        return jsonify(error="Error", mensaje="Error interno del servicio"), 500

    return app

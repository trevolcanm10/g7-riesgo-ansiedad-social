import logging
from typing import Optional

from flask import Flask, jsonify, request
from pydantic import ValidationError as PydanticValidationError
from werkzeug.exceptions import BadRequest, HTTPException

from app.api.routes.solicitudes_router import create_solicitudes_blueprint
from app.application.interfaces.token_service_port import ITokenService
from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.config.settings import Config
from app.domain.errors import (
    ConflictError,
    ForbiddenError,
    NotFoundError,
    ValidationError as DomainValidationError,
)
from app.infrastructure.auth.jwt_token_service import JwtTokenService
from app.infrastructure.ml.scikit_classifier import ScikitLocalClassifier
from app.infrastructure.persistence.db_models import db
from app.infrastructure.persistence.repository import SQLAlchemySolicitudRepository


def _parse_allowed_origins(raw: str) -> set[str]:
    return {origin.strip().rstrip("/") for origin in raw.split(",") if origin.strip()}


def create_app(
    config_class=Config,
    token_service: Optional[ITokenService] = None,
) -> Flask:
    app = Flask(__name__)
    app.config.from_object(config_class)

    allowed_origins = _parse_allowed_origins(app.config.get("CORS_ALLOW_ORIGIN", ""))

    @app.before_request
    def handle_preflight():
        if request.method == "OPTIONS":
            return app.make_default_options_response()

    @app.after_request
    def add_cors_headers(response):
        origin = (request.headers.get("Origin") or "").rstrip("/")
        if origin and origin in allowed_origins:
            response.headers["Access-Control-Allow-Origin"] = origin
            response.headers["Vary"] = "Origin"
            response.headers["Access-Control-Allow-Methods"] = "GET, POST, PATCH, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = (
                "Content-Type, Authorization, Ocp-Apim-Subscription-Key"
            )
        return response

    db.init_app(app)
    if app.config.get("AUTO_CREATE_TABLES", False):
        with app.app_context():
            db.create_all()

    repository = SQLAlchemySolicitudRepository()
    classifier = ScikitLocalClassifier()
    tokens = token_service or JwtTokenService(app.config.get("JWT_SECRET", ""))
    help_lines = app.config.get("HELP_LINES")
    use_cases = OrientacionUseCases(repository, classifier, help_lines=help_lines)

    @app.get("/health")
    def health():
        db_ok = repository.ping()
        return (
            jsonify(
                service="orientacion",
                status="OK" if db_ok else "ERROR",
                database="OK" if db_ok else "UNAVAILABLE",
                classifierModel=classifier.model_status,
            ),
            200 if db_ok else 503,
        )

    solicitudes_bp = create_solicitudes_blueprint(use_cases, tokens)
    app.register_blueprint(solicitudes_bp, url_prefix="/api/v1/orientacion/solicitudes")

    @app.errorhandler(PydanticValidationError)
    def handle_pydantic_error(exc: PydanticValidationError):
        errors = [
            {
                "field": ".".join(str(loc) for loc in err.get("loc", ())) or "body",
                "message": err.get("msg", "Valor inválido"),
            }
            for err in exc.errors(include_url=False)
        ]
        return jsonify(message="Errores de validación", errors=errors), 400

    @app.errorhandler(DomainValidationError)
    def handle_domain_validation(exc: DomainValidationError):
        return jsonify(message=str(exc)), 400

    @app.errorhandler(ForbiddenError)
    def handle_forbidden(exc: ForbiddenError):
        return jsonify(message=str(exc)), 403

    @app.errorhandler(NotFoundError)
    def handle_not_found(exc: NotFoundError):
        return jsonify(message=str(exc)), 404

    @app.errorhandler(ConflictError)
    def handle_conflict(exc: ConflictError):
        return jsonify(message=str(exc)), 409

    @app.errorhandler(BadRequest)
    def handle_bad_request(_exc: BadRequest):
        return jsonify(message="JSON malformado o Content-Type incorrecto"), 400

    @app.errorhandler(HTTPException)
    def handle_http_exception(exc: HTTPException):
        return jsonify(message=exc.description), exc.code

    @app.errorhandler(Exception)
    def handle_unexpected_error(_exc: Exception):
        app.logger.exception("Error interno no controlado")
        return jsonify(message="Error interno del servidor"), 500

    return app


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    app = create_app()
    app.run(host="0.0.0.0", port=Config.PORT, debug=Config.FLASK_DEBUG)

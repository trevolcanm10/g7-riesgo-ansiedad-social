from __future__ import annotations

import logging
import time
from functools import wraps
from typing import Any, Callable

from flask import Flask, g, jsonify, request
from werkzeug.exceptions import HTTPException

from ..config import Settings
from ..domain.entities import ROLES, UserContext
from ..domain.errors import DomainError, ForbiddenError, ValidationError
from ..infrastructure.jwt_service import verify_access_token
from ..application.academic_support_service import AcademicSupportService


def _json_body() -> Any:
    body = request.get_json(silent=True)
    if not isinstance(body, dict):
        raise ValidationError("El cuerpo debe ser un objeto JSON")
    return body


def create_http_app(
    settings: Settings,
    service: AcademicSupportService,
    repository: Any,
) -> Flask:
    app = Flask(__name__)
    app.config["JSON_AS_ASCII"] = False
    app.logger.setLevel(logging.INFO)

    @app.before_request
    def start_timer() -> None:
        g.request_started = time.perf_counter()

    @app.after_request
    def log_request(response):
        elapsed_ms = round((time.perf_counter() - g.get("request_started", time.perf_counter())) * 1000, 2)
        app.logger.info(
            "http_request method=%s path=%s status=%s duration_ms=%s",
            request.method,
            request.path,
            response.status_code,
            elapsed_ms,
        )
        return response

    @app.errorhandler(DomainError)
    def handle_domain_error(error: DomainError):
        payload: dict[str, Any] = {"message": error.message}
        if isinstance(error, ValidationError) and error.errors:
            payload["errors"] = error.errors
        return jsonify(payload), error.status_code

    @app.errorhandler(HTTPException)
    def handle_http_error(error: HTTPException):
        return jsonify({"message": error.name}), error.code or 500

    @app.errorhandler(Exception)
    def handle_unexpected_error(error: Exception):
        app.logger.error(
            "request_failed error_type=%s path=%s",
            type(error).__name__,
            request.path,
        )
        return jsonify({"message": "Error interno del servicio"}), 500

    def authenticated(allowed_roles: set[str] | None = None):
        def decorator(handler: Callable):
            @wraps(handler)
            def wrapper(*args, **kwargs):
                authorization = request.headers.get("Authorization", "")
                parts = authorization.split()
                if len(parts) != 2 or parts[0] != "Bearer":
                    raise DomainError("Token de autenticación requerido o inválido", 401)
                token_user = verify_access_token(parts[1], settings.jwt_secret)
                role = token_user["role"]
                if role not in ROLES:
                    raise DomainError("Token inválido o expirado", 401)
                if allowed_roles is not None and role not in allowed_roles:
                    raise ForbiddenError()
                g.user = UserContext(
                    user_id=token_user["user_id"],
                    role=role,
                )
                return handler(*args, **kwargs)
            return wrapper
        return decorator

    student_roles = {"ESTUDIANTE"}
    staff_roles = {"PERSONAL_UNAYOE", "ADMINISTRADOR"}
    all_roles = student_roles | staff_roles

    @app.get("/health")
    def health():
        try:
            repository.ping()
        except Exception as error:
            app.logger.error("database_unavailable error_type=%s", type(error).__name__)
            return jsonify(
                {
                    "service": "academic-support",
                    "status": "ERROR",
                    "database": "UNAVAILABLE",
                }
            ), 503
        return jsonify(
            {
                "service": "academic-support",
                "status": "OK",
                "database": "OK",
            }
        ), 200

    @app.get("/resources")
    @authenticated(all_roles)
    def list_resources():
        return jsonify(service.list_resources(request.args.to_dict())), 200

    @app.get("/resources/<int:resource_id>")
    @authenticated(all_roles)
    def get_resource(resource_id: int):
        return jsonify(service.get_resource(resource_id)), 200

    @app.post("/resources")
    @authenticated(all_roles)
    def create_resource():
        result = service.create_resource(g.user, _json_body())
        return jsonify(result), 201

    @app.patch("/resources/<int:resource_id>")
    @authenticated(all_roles)
    def update_resource(resource_id: int):
        result = service.update_resource(g.user, resource_id, _json_body())
        return jsonify(result), 200

    @app.delete("/resources/<int:resource_id>")
    @authenticated(all_roles)
    def cancel_resource(resource_id: int):
        service.cancel_resource(g.user, resource_id)
        return "", 204

    @app.get("/students/me/preferences")
    @authenticated(student_roles)
    def get_preferences():
        return jsonify(service.get_preferences(g.user)), 200

    @app.put("/students/me/preferences")
    @authenticated(student_roles)
    def save_preferences():
        return jsonify(service.save_preferences(g.user, _json_body())), 200

    @app.get("/recommendations")
    @authenticated(student_roles)
    def recommendations():
        try:
            limit = int(request.args.get("limit", "10"))
        except ValueError as error:
            raise ValidationError("limit debe ser un entero") from error
        return jsonify(service.recommendations(g.user, limit)), 200

    @app.post("/interactions")
    @authenticated(student_roles)
    def record_interaction():
        return jsonify(service.record_interaction(g.user, _json_body())), 201

    @app.post("/workshops/<int:resource_id>/enroll")
    @authenticated(student_roles)
    def enroll(resource_id: int):
        result = service.enroll(g.user, resource_id)
        return jsonify(result), 201

    @app.delete("/workshops/<int:resource_id>/enroll")
    @authenticated(student_roles)
    def cancel_enrollment(resource_id: int):
        service.cancel_enrollment(g.user, resource_id)
        return "", 204

    @app.get("/students/me/enrollments")
    @authenticated(student_roles)
    def enrollments():
        return jsonify({"items": service.enrollments(g.user)}), 200

    return app

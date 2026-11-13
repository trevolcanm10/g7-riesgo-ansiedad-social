from flask import Flask, jsonify, request
from werkzeug.exceptions import BadRequest, HTTPException

from src.application.use_cases.create_activity import CreateActivityUseCase
from src.application.use_cases.list_activities import ListActivitiesUseCase
from src.application.use_cases.get_activity import GetActivityUseCase
from src.application.use_cases.update_activity import UpdateActivityUseCase
from src.application.use_cases.delete_activity import DeleteActivityUseCase
from src.application.use_cases.classify_week import ClassifyWeekUseCase
from src.application.use_cases.get_preventive_alerts import GetPreventiveAlertsUseCase
from src.domain.errors import (
    ActivityNotFoundError, InvalidActivityError, ModelsUnavailableError,
)
from src.presentation.validation import (
    validate_activity_payload,
    validate_classify_payload,
)


def create_http_app(
    create_uc: CreateActivityUseCase,
    list_uc: ListActivitiesUseCase,
    get_uc: GetActivityUseCase,
    update_uc: UpdateActivityUseCase,
    delete_uc: DeleteActivityUseCase,
    classify_uc: ClassifyWeekUseCase | None,
    alerts_uc: GetPreventiveAlertsUseCase,
    models_available: bool,
    token_service,
) -> Flask:
    app = Flask(__name__)

    def require_auth():
        auth = request.headers.get("Authorization", "")
        parts = auth.split(" ")
        if len(parts) != 2 or parts[0] != "Bearer":
            return None
        try:
            return token_service.verify_access_token(parts[1])
        except Exception:
            return None

    def activity_to_dict(activity) -> dict:
        return {
            "id": activity.id,
            "user_id": activity.user_id,
            "title": activity.title,
            "course": activity.course,
            "activity_type": activity.activity_type,
            "activity_date": (
                activity.activity_date.isoformat()
                if activity.activity_date else None
            ),
            "estimated_hours": activity.estimated_hours,
            "priority": activity.priority,
            "description": activity.description,
            "completed": activity.completed,
            "created_at": (
                activity.created_at.isoformat() if activity.created_at else None
            ),
        }

    @app.get("/health")
    def health():
        return jsonify(
            service="academic-agenda",
            status="OK",
            ml_predictor_available=models_available,
        ), 200

    @app.post("/auth/login")
    def login():
        try:
            body = request.get_json(force=True)
        except Exception:
            return jsonify(error="Error", mensaje="JSON inválido"), 400
        user_id = body.get("user_id")
        role = body.get("role", "ESTUDIANTE")
        if not user_id:
            return jsonify(error="Error", mensaje="user_id requerido"), 400
        token = token_service.generate_access_token(int(user_id), str(role))
        return jsonify(accessToken=token), 200

    @app.post("/actividades")
    def create_activity():
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        try:
            data = validate_activity_payload(request.get_json(), partial=False)
        except (ValueError, BadRequest) as exc:
            return jsonify(error="Error", mensaje=str(exc)), 400
        try:
            activity = create_uc.execute(
                user_id=int(payload["user_id"]),
                title=data["title"],
                course=data["course"],
                activity_type=data["activity_type"],
                activity_date=data["activity_date"],
                estimated_hours=data["estimated_hours"],
                priority=data["priority"],
                description=data.get("description", ""),
                completed=data.get("completed", False),
            )
            return jsonify(activity_to_dict(activity)), 201
        except InvalidActivityError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 400

    @app.get("/actividades")
    def list_activities():
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        activities = list_uc.execute(int(payload["user_id"]))
        return jsonify([activity_to_dict(a) for a in activities]), 200

    @app.get("/actividades/<int:activity_id>")
    def get_activity(activity_id: int):
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        try:
            activity = get_uc.execute(activity_id, int(payload["user_id"]))
        except ActivityNotFoundError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 404
        return jsonify(activity_to_dict(activity)), 200

    @app.patch("/actividades/<int:activity_id>")
    def update_activity(activity_id: int):
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        try:
            data = validate_activity_payload(request.get_json(), partial=True)
        except (ValueError, BadRequest) as exc:
            return jsonify(error="Error", mensaje=str(exc)), 400
        try:
            activity = update_uc.execute(
                activity_id, int(payload["user_id"]), data
            )
        except ActivityNotFoundError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 404
        if activity is None:
            return jsonify(error="Error", mensaje="No se pudo actualizar"), 404
        return jsonify(activity_to_dict(activity)), 200

    @app.delete("/actividades/<int:activity_id>")
    def delete_activity(activity_id: int):
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        try:
            deleted = delete_uc.execute(activity_id, int(payload["user_id"]))
        except ActivityNotFoundError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 404
        if not deleted:
            return jsonify(error="Error", mensaje="No se pudo eliminar"), 404
        return jsonify(mensaje="Actividad eliminada"), 200

    @app.post("/clasificacion/semanal")
    def classify_week():
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        if classify_uc is None or not models_available:
            return jsonify(
                error="Error",
                mensaje="Predictor de carga semanal no disponible",
            ), 503
        try:
            data = validate_classify_payload(request.get_json())
        except (ValueError, BadRequest) as exc:
            return jsonify(error="Error", mensaje=str(exc)), 400
        try:
            result = classify_uc.execute(data)
            return jsonify(result), 200
        except ModelsUnavailableError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 503


    @app.post("/alertas/preventivas")
    def get_preventive_alerts():
        payload = require_auth()
        if not payload:
            return jsonify(error="Error", mensaje="Autenticación requerida"), 401
        if classify_uc is None or not models_available:
            return jsonify(
                error="Error",
                mensaje="Predictor de carga semanal no disponible",
            ), 503
        try:
            data = validate_classify_payload(request.get_json())
        except (ValueError, BadRequest) as exc:
            return jsonify(error="Error", mensaje=str(exc)), 400
        try:
            result = alerts_uc.execute(data)
            return jsonify(result), 200
        except ModelsUnavailableError as exc:
            return jsonify(error="Error", mensaje=str(exc)), 503

    @app.errorhandler(Exception)
    def handle_error(exc):
        if isinstance(exc, HTTPException):
            return jsonify(error="Error", mensaje=exc.description), exc.code
        app.logger.error("Error interno: %s", exc)
        return jsonify(error="Error", mensaje="Error interno del servidor"), 500

    return app

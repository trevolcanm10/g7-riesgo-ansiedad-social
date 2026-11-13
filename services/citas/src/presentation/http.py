"""Adaptador HTTP (Flask). Mismo contrato de errores que los servicios Node: {"message": ...}."""
from datetime import datetime, timezone
from functools import wraps
from typing import Callable

from flask import Flask, g, jsonify, request
from werkzeug.exceptions import BadRequest, HTTPException

from src.application.services import AppointmentService, SlotService
from src.domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from src.domain.model import Appointment, Role, Slot
from src.domain.ports import TokenService

STAFF = (Role.PERSONAL_UNAYOE.value, Role.ADMINISTRADOR.value)


def _iso(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def parse_datetime(value, field: str) -> datetime:
    """ISO 8601 con zona horaria obligatoria (p. ej. 2026-11-20T15:00:00-05:00 o ...Z)."""
    if not isinstance(value, str):
        raise ValidationError(f"{field} debe ser una fecha ISO 8601")
    try:
        dt = datetime.fromisoformat(value.strip().replace("Z", "+00:00"))
        if dt.tzinfo is None:
            raise ValidationError(f"{field} debe incluir zona horaria (por ejemplo -05:00 o Z)")
        return dt.astimezone(timezone.utc)
    except (ValueError, OverflowError):   # OverflowError: fechas en los extremos del calendario
        raise ValidationError(f"{field} no es una fecha ISO 8601 válida")


def parse_int(value, field: str) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or value <= 0:
        raise ValidationError(f"{field} debe ser un entero positivo")
    return value


def parse_query_int(value: str, field: str) -> int:
    """Entero positivo recibido por query string (solo dígitos ASCII)."""
    if not (value.isascii() and value.isdigit()):
        raise ValidationError(f"{field} debe ser un entero positivo")
    return parse_int(int(value), field)


def slot_json(s: Slot) -> dict:
    return {"id": s.id, "staffUserId": s.staff_user_id, "startAt": _iso(s.start_at),
            "endAt": _iso(s.end_at), "status": s.status.value}


def appointment_json(a: Appointment) -> dict:
    return {"id": a.id, "studentUserId": a.student_user_id, "staffUserId": a.staff_user_id,
            "slotId": a.slot_id, "startAt": _iso(a.start_at), "endAt": _iso(a.end_at),
            "status": a.status.value, "priority": a.priority.value, "reason": a.reason,
            "rescheduleCount": a.reschedule_count, "cancelReason": a.cancel_reason,
            "createdAt": _iso(a.created_at), "updatedAt": _iso(a.updated_at)}


def reminder_json(item: dict) -> dict:
    a = item["appointment"]
    return {"appointmentId": a.id, "staffUserId": a.staff_user_id, "startAt": _iso(a.start_at),
            "endAt": _iso(a.end_at), "status": a.status.value, "hoursUntil": item["hoursUntil"],
            "dueNow": item["dueNow"], "canChange": item["canChange"],
            "canChangeUntil": _iso(item["canChangeUntil"])}


def create_http_app(slots: SlotService, appointments: AppointmentService,
                    tokens: TokenService, db_ping: Callable[[], bool]) -> Flask:
    app = Flask(__name__)

    def auth(*roles: str):
        def decorator(fn):
            @wraps(fn)
            def wrapper(*args, **kwargs):
                header = request.headers.get("Authorization")
                if not header:
                    return jsonify(message="Token de autenticación requerido"), 401
                parts = header.split(" ")
                if len(parts) != 2 or parts[0] != "Bearer" or not parts[1]:
                    return jsonify(message="Formato de token inválido"), 401
                try:
                    g.user_id, g.role = tokens.verify_access_token(parts[1])
                except ValueError:
                    return jsonify(message="Token inválido o expirado"), 401
                if roles and g.role not in roles:
                    return jsonify(message="No tienes permisos para realizar esta operación"), 403
                return fn(*args, **kwargs)
            return wrapper
        return decorator

    def body() -> dict:
        data = request.get_json(silent=False)
        if not isinstance(data, dict):
            raise ValidationError("El cuerpo debe ser un objeto JSON")
        return data

    @app.get("/health")
    def health():
        ok = db_ping()
        return jsonify(service="citas", status="OK" if ok else "ERROR",
                       database="OK" if ok else "UNAVAILABLE",
                       noShowModel=appointments.model_name), 200 if ok else 503

    # ---------------- horarios ----------------
    @app.get("/slots")
    @auth()
    def list_slots():
        start = parse_datetime(request.args["from"], "from") if "from" in request.args else None
        end = parse_datetime(request.args["to"], "to") if "to" in request.args else None
        staff = parse_query_int(request.args["staffUserId"], "staffUserId") \
            if "staffUserId" in request.args else None
        return jsonify([slot_json(s) for s in slots.list_free(start, end, staff)])

    @app.post("/slots")
    @auth(*STAFF)
    def publish_slots():
        data = body()
        raw = data.get("startAts")
        if not isinstance(raw, list):
            raise ValidationError("startAts debe ser una lista de fechas ISO 8601")
        starts = [parse_datetime(v, "startAts") for v in raw]
        staff = parse_int(data["staffUserId"], "staffUserId") if "staffUserId" in data else None
        created = slots.publish(g.user_id, g.role, starts, staff)
        return jsonify([slot_json(s) for s in created]), 201

    # ---------------- citas ----------------
    @app.post("/appointments")
    @auth(Role.ESTUDIANTE.value)
    def request_appointment():
        data = body()
        appt = appointments.request(g.user_id, parse_int(data.get("slotId"), "slotId"),
                                    data.get("priority"), data.get("reason"))
        return jsonify(appointment_json(appt)), 201

    @app.get("/appointments/me")
    @auth(Role.ESTUDIANTE.value)
    def my_appointments():
        return jsonify([appointment_json(a) for a in appointments.list_mine(g.user_id)])

    @app.get("/appointments/me/reminders")
    @auth(Role.ESTUDIANTE.value)
    def my_reminders():
        return jsonify([reminder_json(i) for i in appointments.reminders(g.user_id)])

    @app.get("/appointments")
    @auth(*STAFF)
    def agenda():
        start = parse_datetime(request.args["from"], "from") if "from" in request.args else None
        end = parse_datetime(request.args["to"], "to") if "to" in request.args else None
        items = appointments.agenda(g.user_id, g.role, request.args.get("status"), start, end)
        return jsonify([appointment_json(a) for a in items])

    @app.patch("/appointments/<int:appointment_id>/cancel")
    @auth()
    def cancel(appointment_id):
        data = request.get_json(silent=True) or {}
        reason = data.get("reason") if isinstance(data, dict) else None
        return jsonify(appointment_json(
            appointments.cancel(appointment_id, g.user_id, g.role, reason)))

    @app.patch("/appointments/<int:appointment_id>/reschedule")
    @auth(Role.ESTUDIANTE.value)
    def reschedule(appointment_id):
        slot_id = parse_int(body().get("slotId"), "slotId")
        return jsonify(appointment_json(
            appointments.reschedule(appointment_id, g.user_id, g.role, slot_id)))

    @app.patch("/appointments/<int:appointment_id>/status")
    @auth(*STAFF)
    def change_status(appointment_id):
        status = body().get("status")
        if not isinstance(status, str):
            raise ValidationError("status es obligatorio")
        return jsonify(appointment_json(
            appointments.change_status(appointment_id, g.user_id, g.role, status)))

    @app.get("/appointments/<int:appointment_id>/no-show-risk")
    @auth(*STAFF)
    def no_show_risk(appointment_id):
        return jsonify(appointments.no_show_risk(appointment_id, g.user_id, g.role))

    # ---------------- errores ----------------
    @app.errorhandler(Exception)
    def handle_error(exc):
        if isinstance(exc, ValidationError):
            return jsonify(message=str(exc)), 400
        if isinstance(exc, ForbiddenError):
            return jsonify(message=str(exc)), 403
        if isinstance(exc, NotFoundError):
            return jsonify(message=str(exc)), 404
        if isinstance(exc, ConflictError):
            return jsonify(message=str(exc)), 409
        if isinstance(exc, BadRequest):
            return jsonify(message="JSON malformado o Content-Type incorrecto"), 400
        if isinstance(exc, HTTPException):
            return jsonify(message=exc.description), exc.code
        app.logger.exception("Error no controlado")
        return jsonify(message="Error interno del servidor"), 500

    return app

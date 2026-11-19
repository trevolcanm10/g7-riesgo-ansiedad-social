from functools import wraps
from flask import Blueprint, g, jsonify, request

from app.api.schemas.solicitud_schemas import SolicitudAtenderDTO, SolicitudCreateDTO
from app.application.interfaces.token_service_port import ITokenService
from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.domain.entities.solicitud import Role
from app.domain.errors import ValidationError as DomainValidationError

STAFF_ROLES = (Role.PERSONAL_UNAYOE.value, Role.ADMINISTRADOR.value)


def _parse_query_int(value: str, field: str) -> int:
    if not (value.isascii() and value.isdigit()):
        raise DomainValidationError(f"{field} debe ser un entero positivo")
    parsed = int(value)
    if parsed <= 0:
        raise DomainValidationError(f"{field} debe ser un entero positivo")
    return parsed


def _parse_non_negative_int(value: str, field: str) -> int:
    if not (value.isascii() and value.isdigit()):
        raise DomainValidationError(f"{field} debe ser un entero no negativo")
    return int(value)


def create_solicitudes_blueprint(
    use_cases: OrientacionUseCases,
    token_service: ITokenService,
) -> Blueprint:
    bp = Blueprint("solicitudes", __name__)

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
                    g.user_id, g.role = token_service.verify_access_token(parts[1])
                except ValueError:
                    return jsonify(message="Token inválido o expirado"), 401
                if roles and g.role not in roles:
                    return jsonify(
                        message="No tienes permisos para realizar esta operación"
                    ), 403
                return fn(*args, **kwargs)

            return wrapper

        return decorator

    def _json_body() -> dict:
        data = request.get_json(silent=False)
        if not isinstance(data, dict):
            raise DomainValidationError("El cuerpo debe ser un objeto JSON")
        return data

    @bp.route("", methods=["POST"])
    @auth(Role.ESTUDIANTE.value)
    def crear_solicitud():
        dto = SolicitudCreateDTO(**_json_body())
        result = use_cases.crear_solicitud(
            estudiante_id=g.user_id,
            mensaje=dto.mensaje,
            comparte_evaluacion=dto.comparte_evaluacion_riesgo,
            eval_id=dto.evaluacion_riesgo_id,
        )

        resp = result["solicitud"].to_dict()
        if result["urgencia"]:
            resp["alertas_urgencia"] = {
                "coincidencias": result["urgencia"].coincidencias,
                "lineas_ayuda": result["urgencia"].lineas_ayuda,
            }
        return jsonify(resp), 201

    @bp.route("", methods=["GET"])
    @auth()
    def listar_solicitudes():
        estado = request.args.get("estado") or None
        prioridad = request.args.get("prioridad") or None
        raw_est = request.args.get("estudiante_id")
        estudiante_id = (
            _parse_query_int(raw_est, "estudiante_id") if raw_est else None
        )
        limit = (
            _parse_query_int(request.args["limit"], "limit")
            if "limit" in request.args
            else 50
        )
        offset = (
            _parse_non_negative_int(request.args["offset"], "offset")
            if "offset" in request.args
            else 0
        )

        solicitudes = use_cases.listar_solicitudes(
            actor_id=g.user_id,
            actor_role=g.role,
            estado=estado,
            prioridad=prioridad,
            estudiante_id=estudiante_id,
            limit=limit,
            offset=offset,
        )
        return jsonify([s.to_dict() for s in solicitudes]), 200

    @bp.route("/<int:id>", methods=["GET"])
    @auth()
    def obtener_solicitud(id: int):
        solicitud = use_cases.obtener_solicitud(
            solicitud_id=id, actor_id=g.user_id, actor_role=g.role
        )
        return jsonify(solicitud.to_dict()), 200

    @bp.route("/<int:id>/atender", methods=["PATCH"])
    @auth(*STAFF_ROLES)
    def atender_solicitud(id: int):
        dto = SolicitudAtenderDTO(**_json_body())
        solicitud = use_cases.atender_solicitud(
            solicitud_id=id,
            respuesta=dto.respuesta_escrita,
            orientador_id=g.user_id,
            actor_role=g.role,
            tema_conf=dto.tema_confirmado,
            prio_conf=dto.prioridad_confirmada,
        )
        return jsonify(solicitud.to_dict()), 200

    @bp.route("/metricas/conteo-temas", methods=["GET"])
    @auth(*STAFF_ROLES)
    def conteo_temas():
        metricas = use_cases.metricas_temas(actor_role=g.role)
        return jsonify(metricas), 200

    return bp

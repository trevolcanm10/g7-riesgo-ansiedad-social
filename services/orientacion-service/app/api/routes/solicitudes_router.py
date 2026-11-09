from flask import Blueprint, request, jsonify
from app.application.use_cases.solicitud_use_cases import OrientacionUseCases
from app.api.schemas.solicitud_schemas import SolicitudCreateDTO, SolicitudAtenderDTO
from pydantic import ValidationError

def create_solicitudes_blueprint(use_cases: OrientacionUseCases) -> Blueprint:
    bp = Blueprint('solicitudes', __name__)

    @bp.route('', methods=['POST'])
    def crear_solicitud():
        try:
            payload = request.get_json(silent=True)
            data = payload if isinstance(payload, dict) else {}
            dto = SolicitudCreateDTO(**data)
            result = use_cases.crear_solicitud(
                estudiante_id=dto.estudiante_id,
                mensaje=dto.mensaje,
                comparte_evaluacion=dto.comparte_evaluacion_riesgo,
                eval_id=dto.evaluacion_riesgo_id
            )

            resp = result["solicitud"].to_dict()
            if result["urgencia"]:
                resp["alertas_urgencia"] = {
                    "coincidencias": result["urgencia"].coincidencias,
                    "lineas_ayuda": result["urgencia"].lineas_ayuda
                }
            return jsonify(resp), 201
        except ValidationError as e:
            return jsonify({"error": "Errores de validación", "detalles": e.errors()}), 400
        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500

    @bp.route('', methods=['GET'])
    def listar_solicitudes():
        estado = request.args.get('estado')
        prioridad = request.args.get('prioridad')
        estudiante_id = request.args.get('estudiante_id')
        solicitudes = use_cases.listar_solicitudes(estado, prioridad, estudiante_id)
        return jsonify([s.to_dict() for s in solicitudes]), 200

    @bp.route('/<int:id>', methods=['GET'])
    def obtener_solicitud(id):
        solicitud = use_cases.obtener_solicitud(id)
        if not solicitud:
            return jsonify({"error": "Solicitud no encontrada"}), 404
        return jsonify(solicitud.to_dict()), 200

    @bp.route('/<int:id>/atender', methods=['PATCH'])
    def atender_solicitud(id):
        try:
            payload = request.get_json(silent=True)
            data = payload if isinstance(payload, dict) else {}
            dto = SolicitudAtenderDTO(**data)
            solicitud = use_cases.atender_solicitud(
                id=id,
                respuesta=dto.respuesta_escrita,
                orientador=dto.atendido_por,
                tema_conf=dto.tema_confirmado,
                prio_conf=dto.prioridad_confirmada
            )
            if not solicitud:
                return jsonify({"error": "Solicitud no encontrada"}), 404
            return jsonify(solicitud.to_dict()), 200
        except ValidationError as e:
            return jsonify({"error": "Errores de validación", "detalles": e.errors()}), 400
        except Exception as e:
            return jsonify({"error": "Error interno del servidor", "detalle": str(e)}), 500

    @bp.route('/metricas/conteo-temas', methods=['GET'])
    def conteo_temas():
        metricas = use_cases.metricas_temas()
        return jsonify(metricas), 200

    return bp

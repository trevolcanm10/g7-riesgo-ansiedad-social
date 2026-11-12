"""Rutas HTTP del Panel Institucional.

Todas las rutas salvo ``/health`` exigen un token JWT con rol institucional.
"""

from __future__ import annotations

from flask import Blueprint, jsonify, request

from app.application.use_cases.generar_informe import GenerarInforme
from app.application.use_cases.listar_atenciones import ListarAtenciones
from app.application.use_cases.obtener_estadisticas import ObtenerEstadisticas
from app.application.use_cases.registrar_atencion import RegistrarAtencion
from app.presentation.dto.schemas import AtencionCreateDTO
from app.presentation.middlewares.auth_middleware import requiere_autorizacion, token_actual


def crear_blueprint_panel(
    registrar_atencion: RegistrarAtencion,
    obtener_estadisticas: ObtenerEstadisticas,
    generar_informe: GenerarInforme,
    listar_atenciones: ListarAtenciones,
) -> Blueprint:
    """Construye el blueprint con los casos de uso inyectados."""
    blueprint = Blueprint("panel", __name__)

    @blueprint.post("/atencion")
    @requiere_autorizacion
    def registrar_atencion_route():
        """Registra una atencion institucional a un estudiante."""
        cuerpo = request.get_json(silent=True)
        if not isinstance(cuerpo, dict):
            return jsonify({"error": "El cuerpo de la peticion debe ser un objeto JSON."}), 400

        try:
            dto = AtencionCreateDTO(**cuerpo)
        except Exception as error:
            return jsonify({"error": "Datos de la atencion no validos.", "detalles": _detalles(error)}), 400

        indicadores = dto.indicadores.model_dump(exclude_none=True) if dto.indicadores else {}

        atencion = registrar_atencion.execute(
            estudiante_codigo=dto.estudiante_codigo,
            modalidad=dto.modalidad,
            tipo=dto.tipo,
            fecha_atencion=dto.fecha_atencion,
            indicadores=indicadores,
            notas=dto.notas,
            seguimiento_requerido=dto.seguimiento_requerido,
            token=token_actual(),
        )

        return jsonify(atencion.to_dict()), 201

    @blueprint.get("/estadisticas")
    @requiere_autorizacion
    def obtener_estadisticas_route():
        """Devuelve los indicadores anonimizados del panel.

        Los grupos con menos de cinco estudiantes se omiten.
        """
        periodo = request.args.get("periodo")
        if periodo is not None and not _periodo_valido(periodo):
            return jsonify({"error": "El periodo debe tener el formato YYYY-MM."}), 400

        return jsonify(obtener_estadisticas.execute(periodo)), 200

    @blueprint.get("/informe")
    @requiere_autorizacion
    def generar_informe_route():
        """Genera y devuelve el informe CSV del periodo."""
        periodo = request.args.get("periodo")
        if periodo is not None and not _periodo_valido(periodo):
            return jsonify({"error": "El periodo debe tener el formato YYYY-MM."}), 400

        nombre, contenido = generar_informe.execute(periodo)

        return app_response_csv(nombre, contenido)

    @blueprint.get("/atenciones")
    @requiere_autorizacion
    def listar_atenciones_route():
        """Lista las atenciones registradas, con paginacion y filtros."""
        try:
            limite = min(int(request.args.get("limite", 50)), 200)
            offset = max(int(request.args.get("offset", 0)), 0)
        except ValueError:
            return jsonify({"error": "Los parametros limite y offset deben ser numericos."}), 400

        tipo = request.args.get("tipo")
        modalidad = request.args.get("modalidad")
        periodo = request.args.get("periodo")

        if periodo is not None and not _periodo_valido(periodo):
            return jsonify({"error": "El periodo debe tener el formato YYYY-MM."}), 400

        atenciones, total = listar_atenciones.execute(
            limite=limite, offset=offset, tipo=tipo, modalidad=modalidad, periodo=periodo
        )

        return (
            jsonify(
                {
                    "total": total,
                    "limite": limite,
                    "offset": offset,
                    "atenciones": [atencion.to_dict() for atencion in atenciones],
                }
            ),
            200,
        )

    return blueprint


def app_response_csv(nombre: str, contenido: str):
    """Construye la respuesta de descarga del informe CSV."""
    from flask import Response

    return Response(
        contenido,
        mimetype="text/csv; charset=utf-8",
        headers={"Content-Disposition": f'attachment; filename="{nombre}"'},
    )


def _detalles(error: Exception) -> list:
    """Extrae los mensajes de validacion de Pydantic."""
    try:
        return [
            {
                "campo": ".".join(str(parte) for parte in item.get("loc", [])),
                "mensaje": item.get("msg", ""),
            }
            for item in error.errors()
        ]
    except AttributeError:
        return [{"campo": "", "mensaje": str(error)}]


def _periodo_valido(periodo: str) -> bool:
    """Verifica que el periodo tenga el formato ``YYYY-MM``."""
    if len(periodo) != 7 or periodo[4] != "-":
        return False

    anio, mes = periodo[:4], periodo[5:]
    return anio.isdigit() and mes.isdigit() and 1 <= int(mes) <= 12

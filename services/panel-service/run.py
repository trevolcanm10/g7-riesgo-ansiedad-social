"""Punto de entrada del microservicio Panel Institucional.

Assembla las capas (composition root): crea los adaptadores concretos y los
inyecta en los casos de uso.
"""

from __future__ import annotations

import logging
import os
import sys

from flask import Flask, jsonify, request

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from app.application.use_cases.generar_informe import GenerarInforme
from app.application.use_cases.listar_atenciones import ListarAtenciones
from app.application.use_cases.obtener_estadisticas import ObtenerEstadisticas
from app.application.use_cases.obtener_riesgo_por_perfil import ObtenerRiesgoPorPerfil
from app.application.use_cases.registrar_atencion import RegistrarAtencion
from app.config.settings import Config, TestConfig, construir_uri
from app.infrastructure.clients.evaluaciones_riesgo_client import (
    EvaluacionesRiesgoClient,
)
from app.infrastructure.clients.personal_externo_client import PersonalExternoClient
from app.infrastructure.clients.usuarios_client import UsuariosClient
from app.infrastructure.ml.clustering_adapter import ScikitClusteringAdapter
from app.infrastructure.persistence.atencion_repository import SQLAlchemyAtencionRepository
from app.infrastructure.persistence.db_models import db
from app.presentation.routes.panel_routes import crear_blueprint_panel

logging.basicConfig(
    level=os.getenv("LOG_LEVEL", "INFO"),
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


def create_app(config_class=Config, crear_esquema: bool = False) -> Flask:
    """Crea y configura la aplicacion Flask.

    ``crear_esquema`` queda en ``False`` en produccion: el esquema se aplica
    con ``scripts/init_db.py`` a partir de ``db/schema.sql``, de modo que el
    esquema de la base de datos esta versionado y no es implicito.
    """
    app = Flask(__name__)
    app.config.from_object(config_class)

    if not app.config.get("SQLALCHEMY_DATABASE_URI"):
        app.config["SQLALCHEMY_DATABASE_URI"] = construir_uri()

    db.init_app(app)

    if crear_esquema:
        with app.app_context():
            db.create_all()

    @app.before_request
    def manejar_preflight():
        """Responde a las consultas CORS de preflight."""
        if request.method == "OPTIONS":
            return app.make_default_options_response()

    @app.after_request
    def agregar_cors(respuesta):
        """Agrega las cabeceras CORS permitidas por configuracion."""
        origenes = app.config.get("CORS_ALLOW_ORIGIN", "")
        permitidos = [origen.strip() for origen in origenes.split(",") if origen.strip()]

        origen = request.headers.get("Origin")
        if origen and (origen in permitidos or "*" in permitidos):
            respuesta.headers["Access-Control-Allow-Origin"] = origen
            respuesta.headers["Vary"] = "Origin"

        respuesta.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        respuesta.headers["Access-Control-Allow-Headers"] = (
            "Content-Type, Authorization, Ocp-Apim-Subscription-Key"
        )
        return respuesta

    @app.get("/api/panel/health")
    def health():
        """Estado del servicio y de la base de datos."""
        try:
            db.session.execute(db.text("SELECT 1"))
            return jsonify(
                {
                    "service": app.config.get("SERVICE_NAME", "panel"),
                    "status": "OK",
                    "database": "OK",
                }
            ), 200
        except Exception as error:
            logger.error("Error consultando la base de datos en /health: %s", error)
            return jsonify(
                {
                    "service": app.config.get("SERVICE_NAME", "panel"),
                    "status": "ERROR",
                    "database": "UNAVAILABLE",
                }
            ), 503

    # Adaptadores concretos.
    repository = SQLAlchemyAtencionRepository()
    clustering = ScikitClusteringAdapter()
    personal_externo = (
        PersonalExternoClient(app.config.get("USERS_BASE_URL", ""))
        if app.config.get("USERS_BASE_URL")
        else None
    )
    usuarios = (
        UsuariosClient(app.config.get("USERS_BASE_URL", ""))
        if app.config.get("USERS_BASE_URL")
        else None
    )
    evaluaciones_riesgo = (
        EvaluacionesRiesgoClient(app.config.get("RISK_EVALUATION_BASE_URL", ""))
        if app.config.get("RISK_EVALUATION_BASE_URL")
        else None
    )

    # Casos de uso.
    registrar_atencion = RegistrarAtencion(
        repository, clustering, personal_externo, usuarios
    )
    riesgo_por_perfil = (
        ObtenerRiesgoPorPerfil(evaluaciones_riesgo) if evaluaciones_riesgo else None
    )
    obtener_estadisticas = ObtenerEstadisticas(
        repository, clustering, riesgo_por_perfil
    )
    generar_informe = GenerarInforme(repository)
    listar_atenciones = ListarAtenciones(repository)

    blueprint = crear_blueprint_panel(
        registrar_atencion,
        obtener_estadisticas,
        generar_informe,
        listar_atenciones,
    )
    app.register_blueprint(blueprint, url_prefix="/api/panel")

    @app.errorhandler(404)
    def no_encontrado(error):
        """Respuesta uniforme para rutas inexistentes."""
        return jsonify({"error": "Recurso no encontrado."}), 404

    @app.errorhandler(Exception)
    def error_interno(error):
        """Manejo global de errores sin exponer detalles internos."""
        logger.exception("Error interno no controlado: %s", error)
        return jsonify({"error": "Error interno del servidor."}), 500

    return app


if __name__ == "__main__":
    aplicacion = create_app()
    puerto = int(os.getenv("PORT", "5003"))
    debug = os.getenv("FLASK_DEBUG", "false").lower() == "true"

    if not aplicacion.config.get("JWT_SECRET"):
        logger.error("JWT_SECRET no esta configurado: las rutas protegidas no podran validar tokens.")

    logger.info("Panel institucional escuchando en el puerto %s", puerto)
    aplicacion.run(host="0.0.0.0", port=puerto, debug=debug)

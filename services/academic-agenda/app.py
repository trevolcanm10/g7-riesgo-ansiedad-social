"""Composition root: wire use cases, repositories, and HTTP adapter."""
import logging
import os
from pathlib import Path
from dotenv import load_dotenv
from mysql.connector import Error as MySQLError

load_dotenv(Path(__file__).resolve().parent / ".env", override=False)

from src.infrastructure.persistence.mysql_database import MySQLDatabase
from src.infrastructure.persistence.mysql_activity_repository import (
    MySqlActivityRepository,
)
from src.infrastructure.services.jwt_token_service import JwtTokenService
from src.infrastructure.models.ml_predictor import MlWeeklyPredictor
from src.application.use_cases.create_activity import CreateActivityUseCase
from src.application.use_cases.list_activities import ListActivitiesUseCase
from src.application.use_cases.get_activity import GetActivityUseCase
from src.application.use_cases.update_activity import UpdateActivityUseCase
from src.application.use_cases.delete_activity import DeleteActivityUseCase
from src.application.use_cases.classify_week import ClassifyWeekUseCase
from src.application.use_cases.get_preventive_alerts import GetPreventiveAlertsUseCase
from src.presentation.http import create_http_app


def create_app():
    db_enabled = os.environ.get("DB_ENABLED", "true").strip().lower() != "false"
    repository = None
    if db_enabled:
        production = os.environ.get("FLASK_ENV", "").lower() == "production"
        ssl_enabled = os.environ.get(
            "DB_SSL", "true" if production else "false"
        ).strip().lower() == "true"
        try:
            if production and not ssl_enabled:
                raise ValueError("TLS requerido en producción")
            if production and any(not os.environ.get(name) for name in
                                  ("DB_HOST", "DB_USER", "DB_PASSWORD", "DB_NAME")):
                raise ValueError("Configuración de BD incompleta")
            db = MySQLDatabase(
                host=os.environ.get("DB_HOST", "localhost"),
                port=int(os.environ.get("DB_PORT", "3306")),
                user=os.environ.get("DB_USER", "agenda_app"),
                password=os.environ.get("DB_PASSWORD", ""),
                database=os.environ.get("DB_NAME", "riesgo_social_agenda"),
                ssl_enabled=ssl_enabled,
                ssl_ca=os.environ.get("DB_SSL_CA") or None,
            )
            repository = MySqlActivityRepository(db)
        except (MySQLError, OSError, ValueError):
            logging.getLogger(__name__).error(
                "Agenda BD no disponible; el CRUD responderá 503"
            )

    jwt_secret = os.environ.get("JWT_SECRET", "")
    token_service = JwtTokenService(secret=jwt_secret)

    predictor = MlWeeklyPredictor()
    models_available = predictor.is_available
    if not models_available:
        logging.getLogger(__name__).warning(
            "Predictor ML no disponible: %s", predictor.load_error
        )

    create_uc = CreateActivityUseCase(repository) if repository else None
    list_uc = ListActivitiesUseCase(repository) if repository else None
    get_uc = GetActivityUseCase(repository) if repository else None
    update_uc = UpdateActivityUseCase(repository) if repository else None
    delete_uc = DeleteActivityUseCase(repository) if repository else None
    classify_uc = ClassifyWeekUseCase(predictor) if models_available else None
    alerts_uc = GetPreventiveAlertsUseCase(classify_uc) if classify_uc else None
    db_disabled = repository is None

    return create_http_app(
        create_uc=create_uc,
        list_uc=list_uc,
        get_uc=get_uc,
        update_uc=update_uc,
        delete_uc=delete_uc,
        classify_uc=classify_uc,
        alerts_uc=alerts_uc,
        models_available=models_available,
        token_service=token_service,
        db_disabled=db_disabled,
        db_ping=db.ping if repository is not None else None,
    )


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    create_app().run(
        host="0.0.0.0",
        port=int(os.environ.get("PORT", "5004")),
        debug=False,
    )

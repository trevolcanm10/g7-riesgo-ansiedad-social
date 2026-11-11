"""Composition root del microservicio Citas."""
import logging
from pathlib import Path

from src.application.services import AppointmentService, SlotService
from src.config import settings
from src.infrastructure.jwt_token_service import JwtTokenService
from src.infrastructure.logistic_no_show import LogisticNoShowPredictor
from src.infrastructure.rule_based_no_show import RuleBasedNoShowPredictor
from src.presentation.http import create_http_app


def build_predictor(model_path: str = ""):
    """Modelo entrenado si NO_SHOW_MODEL_PATH carga bien; si no, línea base por reglas."""
    if model_path:
        path = Path(model_path)
        if not path.is_absolute():   # relativa a la carpeta del servicio, no al directorio de trabajo
            path = Path(__file__).resolve().parent / path
        try:
            predictor = LogisticNoShowPredictor(path)
            logging.getLogger(__name__).info("Modelo de inasistencia: %s", predictor.MODEL)
            return predictor
        except Exception as exc:   # archivo ausente o artefacto inválido
            logging.getLogger(__name__).warning(
                "No se pudo cargar el modelo (%s); se usa la línea base por reglas", exc)
    return RuleBasedNoShowPredictor()


def create_app():
    tokens = JwtTokenService(settings.JWT_SECRET)
    predictor = build_predictor(settings.NO_SHOW_MODEL_PATH)

    if settings.USE_IN_MEMORY:
        from src.infrastructure.in_memory import (
            InMemoryAppointmentRepository, InMemorySlotRepository,
        )
        logging.getLogger(__name__).warning("USE_IN_MEMORY=true: los datos se pierden al reiniciar")
        slot_repo, appt_repo, ping = InMemorySlotRepository(), InMemoryAppointmentRepository(), (lambda: True)
    else:
        from src.infrastructure.mysql_repositories import (
            Database, MySqlAppointmentRepository, MySqlSlotRepository,
        )
        db = Database(settings.DB_HOST, settings.DB_PORT, settings.DB_NAME,
                      settings.DB_USER, settings.DB_PASSWORD, settings.DB_SSL)
        slot_repo, appt_repo, ping = MySqlSlotRepository(db), MySqlAppointmentRepository(db), db.ping

    return create_http_app(SlotService(slot_repo), AppointmentService(slot_repo, appt_repo, predictor),
                           tokens, ping)


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    create_app().run(host="0.0.0.0", port=settings.PORT, debug=False)

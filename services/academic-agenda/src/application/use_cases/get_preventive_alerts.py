from typing import Mapping

from ...domain.errors import ModelsUnavailableError
from .classify_week import ClassifyWeekUseCase


class PreventiveAlert:
    """Aviso preventivo con severidad."""

    def __init__(self, codigo: str, mensaje: str, severidad: str) -> None:
        self.codigo = codigo
        self.mensaje = mensaje
        self.severidad = severidad

    def to_dict(self) -> dict:
        return {
            "codigo": self.codigo,
            "mensaje": self.mensaje,
            "severidad": self.severidad,
        }


class GetPreventiveAlertsUseCase:
    """Genera avisos preventivos a partir de la clasificacion de carga."""

    def __init__(self, classifier: ClassifyWeekUseCase | None = None) -> None:
        self._classifier = classifier

    def _alerts_by_level(self, level: str) -> list[PreventiveAlert]:
        return {
            "BAJA": [
                PreventiveAlert("AB-001", "Carga academica manejada.", "informacion"),
            ],
            "MODERADA": [
                PreventiveAlert(
                    "AB-002", "Carga semanal elevada; reparte tareas.", "advertencia"
                ),
                PreventiveAlert(
                    "AB-003", "Dedica una sesion de descanso activo.", "advertencia"
                ),
            ],
            "ALTA": [
                PreventiveAlert("AB-004", "Sobrecarga académica importante.", "alto"),
                PreventiveAlert(
                    "AB-005", "Revisa prioridades y difunde trabajos a tiempo.", "alto"
                ),
                PreventiveAlert(
                    "AB-006", "Programa pausas y descanso; evita sacrificios nocturnos.",
                    "alto",
                ),
                PreventiveAlert(
                    "AB-007", "Si la presion persiste, avisa a tutoring o salud mental.",
                    "alto",
                ),
            ],
        }.get(level.upper(), [])

    def execute(self, indicators: Mapping[str, float]) -> dict:
        if self._classifier is None:
            raise ModelsUnavailableError(
                "El clasificador no esta disponible para generar avisos"
            )
        try:
            classificacion = self._classifier.execute(indicators)
        except Exception as exc:
            raise ModelsUnavailableError(
                f"No se pudo clasificar la carga semanal: {exc}"
            ) from exc

        level = str(classificacion.get("nivel_carga", "")).upper()
        return {
            "nivel_carga": level,
            "alertas": [a.to_dict() for a in self._alerts_by_level(level)],
            "recomendacion": self._recommendation(level),
        }

    def _recommendation(self, level: str) -> str:
        if level == "ALTA":
            return (
                "Reducir cargas inmediatas, priorizar examenes y entregas, "
                "y pedir apoyo si la presion aumenta."
            )
        if level == "MODERADA":
            return "Repartir tareas y programar descansos antes de que la carga crezca."
        return "Mantener el equilibrio, revisar la agenda y avanzar con constancia."

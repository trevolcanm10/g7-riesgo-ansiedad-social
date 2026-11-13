from dataclasses import dataclass
from datetime import date, datetime
from typing import Optional


@dataclass
class AcademicActivity:
    """Entidad de dominio que representa una actividad académica."""

    id: Optional[int]
    user_id: int
    title: str
    course: str
    activity_type: str
    activity_date: date
    estimated_hours: float
    priority: str
    description: str
    completed: bool
    created_at: Optional[datetime] = None

    def __post_init__(self) -> None:
        valid_types = {"tarea", "examen", "proyecto", "lectura", "otro"}
        if self.activity_type not in valid_types:
            raise ValueError(f"Tipo de actividad inválido: {self.activity_type}")
        valid_priorities = {"baja", "media", "alta"}
        if self.priority not in valid_priorities:
            raise ValueError(f"Prioridad inválida: {self.priority}")
        if self.estimated_hours < 0:
            raise ValueError("Las horas estimadas no pueden ser negativas")
        if not self.title.strip():
            raise ValueError("El título es obligatorio")
        if not self.course.strip():
            raise ValueError("El curso es obligatorio")
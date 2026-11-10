"""Puertos (interfaces) que implementa la capa de infraestructura."""
from abc import ABC, abstractmethod
from datetime import datetime

from src.domain.model import Appointment, Slot


class SlotRepository(ABC):
    @abstractmethod
    def add(self, slot: Slot) -> Slot: ...

    @abstractmethod
    def get(self, slot_id: int) -> Slot | None: ...

    @abstractmethod
    def list_free(self, start: datetime, end: datetime, staff_user_id: int | None) -> list[Slot]: ...

    @abstractmethod
    def exists(self, staff_user_id: int, start_at: datetime) -> bool: ...

    @abstractmethod
    def reserve(self, slot_id: int) -> bool:
        """Marca LIBRE -> RESERVADO de forma atómica. False si ya no estaba libre."""

    @abstractmethod
    def release(self, slot_id: int) -> None: ...


class AppointmentRepository(ABC):
    @abstractmethod
    def add(self, appointment: Appointment) -> Appointment: ...

    @abstractmethod
    def get(self, appointment_id: int) -> Appointment | None: ...

    @abstractmethod
    def update(self, appointment: Appointment) -> None: ...

    @abstractmethod
    def list_for_student(self, student_user_id: int) -> list[Appointment]: ...

    @abstractmethod
    def list_agenda(self, staff_user_id: int | None, status: str | None,
                    start: datetime | None, end: datetime | None) -> list[Appointment]: ...

    @abstractmethod
    def count_active(self, student_user_id: int) -> int: ...

    @abstractmethod
    def count_by_status(self, student_user_id: int, status: str) -> int: ...

    @abstractmethod
    def add_event(self, appointment_id: int, event_type: str, actor_user_id: int,
                  created_at: datetime) -> None: ...


class NoShowPredictor(ABC):
    @abstractmethod
    def predict(self, features: dict) -> dict:
        """Devuelve {'probability': float, 'factors': [str], 'model': str}."""


class TokenService(ABC):
    @abstractmethod
    def verify_access_token(self, token: str) -> tuple[int, str]:
        """Devuelve (user_id, role) o lanza ValueError si el token no es válido."""

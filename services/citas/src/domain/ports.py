"""Puertos (interfaces) que implementa la capa de infraestructura."""
from abc import ABC, abstractmethod
from datetime import datetime

from src.domain.model import Appointment, AppointmentStatus, Slot


class SlotRepository(ABC):
    @abstractmethod
    def add(self, slot: Slot) -> Slot: ...

    @abstractmethod
    def add_many(self, slots: list[Slot]) -> list[Slot]:
        """Crea todos los horarios o ninguno. Lanza ConflictError si alguno ya existe."""

    @abstractmethod
    def get(self, slot_id: int) -> Slot | None: ...

    @abstractmethod
    def list_free(self, start: datetime, end: datetime, staff_user_id: int | None) -> list[Slot]: ...

    @abstractmethod
    def list_for_staff(self, staff_user_id: int, after: datetime, before: datetime) -> list[Slot]:
        """Horarios del personal con inicio estrictamente entre [after] y [before], en cualquier estado."""

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
    def update(self, appointment: Appointment, *, expect_status: AppointmentStatus | None = None,
               expect_slot_id: int | None = None) -> bool:
        """Guarda la cita. Con expect_* es un bloqueo optimista: solo escribe si en la base
        el estado y/o el horario siguen siendo los esperados. False si otra operación se adelantó."""

    @abstractmethod
    def list_for_student(self, student_user_id: int) -> list[Appointment]: ...

    @abstractmethod
    def list_agenda(self, staff_user_id: int | None, status: str | None,
                    start: datetime | None, end: datetime | None) -> list[Appointment]: ...

    @abstractmethod
    def count_active(self, student_user_id: int) -> int: ...

    @abstractmethod
    def count_by_status(self, student_user_id: int, status: str, *,
                        before: datetime | None = None, exclude_id: int | None = None) -> int:
        """Cuenta citas del estudiante en ese estado. before: solo las que empiezan antes de esa
        fecha; exclude_id: omite una cita (normalmente la que se está evaluando)."""

    @abstractmethod
    def add_event(self, appointment_id: int, event_type: str, actor_user_id: int,
                  created_at: datetime) -> None: ...


class NoShowPredictor(ABC):
    # Probabilidad desde la cual una cita recibe el recordatorio reforzado (top ~20 % en el entrenamiento).
    FLAG_THRESHOLD: float = 0.30

    @abstractmethod
    def predict(self, features: dict) -> dict:
        """Devuelve {'probability': float, 'factors': [str], 'model': str}."""


class TokenService(ABC):
    @abstractmethod
    def verify_access_token(self, token: str) -> tuple[int, str]:
        """Devuelve (user_id, role) o lanza ValueError si el token no es válido."""

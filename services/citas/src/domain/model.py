"""Entidades y reglas del dominio de Citas (sin dependencias de Flask ni MySQL)."""
from dataclasses import dataclass
from datetime import datetime, timedelta
from enum import Enum

SLOT_MINUTES = 30                 # duración fija de una cita
MAX_ACTIVE_APPOINTMENTS = 2       # citas activas por estudiante
MIN_HOURS_TO_CHANGE = 12          # anticipación mínima para cancelar/reprogramar (estudiante)
MAX_SLOTS_PER_REQUEST = 50
MAX_REASON_LENGTH = 200
REMINDER_HOURS = 24               # el recordatorio de una cita aparece desde 24 h antes
REINFORCED_REMINDER_HOURS = 48    # recordatorio reforzado: aparece antes (48 h) para dar margen a reprogramar


class Role(str, Enum):
    ESTUDIANTE = "ESTUDIANTE"
    PERSONAL_UNAYOE = "PERSONAL_UNAYOE"
    ADMINISTRADOR = "ADMINISTRADOR"


class SlotStatus(str, Enum):
    LIBRE = "LIBRE"
    RESERVADO = "RESERVADO"
    BLOQUEADO = "BLOQUEADO"


class AppointmentStatus(str, Enum):
    SOLICITADA = "SOLICITADA"
    CONFIRMADA = "CONFIRMADA"
    ATENDIDA = "ATENDIDA"
    NO_ASISTIO = "NO_ASISTIO"
    CANCELADA = "CANCELADA"


ACTIVE_STATUSES = (AppointmentStatus.SOLICITADA, AppointmentStatus.CONFIRMADA)

# Transiciones que puede hacer el personal de UNAYOE con PATCH /status.
ALLOWED_TRANSITIONS = {
    AppointmentStatus.SOLICITADA: (AppointmentStatus.CONFIRMADA,),
    AppointmentStatus.CONFIRMADA: (AppointmentStatus.ATENDIDA, AppointmentStatus.NO_ASISTIO),
}


class Priority(str, Enum):
    NORMAL = "NORMAL"
    ALTA = "ALTA"   # informativa en la v1: no cambia el orden ni los permisos


@dataclass
class Slot:
    staff_user_id: int
    start_at: datetime            # siempre aware, UTC
    status: SlotStatus = SlotStatus.LIBRE
    id: int | None = None

    @property
    def end_at(self) -> datetime:
        return self.start_at + timedelta(minutes=SLOT_MINUTES)


@dataclass
class Appointment:
    student_user_id: int
    staff_user_id: int
    slot_id: int
    start_at: datetime
    priority: Priority
    reason: str | None
    created_at: datetime
    updated_at: datetime
    status: AppointmentStatus = AppointmentStatus.SOLICITADA
    reschedule_count: int = 0
    cancelled_by: int | None = None
    cancel_reason: str | None = None
    id: int | None = None

    @property
    def end_at(self) -> datetime:
        return self.start_at + timedelta(minutes=SLOT_MINUTES)

    @property
    def is_active(self) -> bool:
        return self.status in ACTIVE_STATUSES

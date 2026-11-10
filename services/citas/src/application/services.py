"""Casos de uso de Citas. Reciben puertos por constructor (sin Flask ni MySQL)."""
from datetime import datetime, timedelta, timezone
from typing import Callable

from src.domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from src.domain.model import (
    ACTIVE_STATUSES, ALLOWED_TRANSITIONS, MAX_ACTIVE_APPOINTMENTS, MAX_REASON_LENGTH,
    MAX_SLOTS_PER_REQUEST, MIN_HOURS_TO_CHANGE, Appointment, AppointmentStatus,
    Priority, Role, Slot, SlotStatus,
)
from src.domain.ports import AppointmentRepository, NoShowPredictor, SlotRepository

Clock = Callable[[], datetime]


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


def _is_staff(role: str) -> bool:
    return role in (Role.PERSONAL_UNAYOE.value, Role.ADMINISTRADOR.value)


class SlotService:
    def __init__(self, slots: SlotRepository, clock: Clock = utc_now):
        self._slots = slots
        self._clock = clock

    def publish(self, actor_id: int, actor_role: str, start_ats: list[datetime],
                staff_user_id: int | None) -> list[Slot]:
        if actor_role == Role.PERSONAL_UNAYOE.value:
            staff_id = actor_id
        elif actor_role == Role.ADMINISTRADOR.value:
            if staff_user_id is None:
                raise ValidationError("staffUserId es obligatorio para el administrador")
            staff_id = staff_user_id
        else:
            raise ForbiddenError("No tienes permisos para realizar esta operación")

        if not start_ats:
            raise ValidationError("Debes enviar al menos un horario en startAts")
        if len(start_ats) > MAX_SLOTS_PER_REQUEST:
            raise ValidationError(f"Máximo {MAX_SLOTS_PER_REQUEST} horarios por solicitud")
        now = self._clock()
        unique = sorted(set(start_ats))
        if len(unique) != len(start_ats):
            raise ValidationError("Hay horarios repetidos en la solicitud")
        for start in unique:
            if start <= now:
                raise ValidationError("Los horarios deben estar en el futuro")
            if start.second or start.microsecond:
                raise ValidationError("Los horarios no deben tener segundos")
            if self._slots.exists(staff_id, start):
                raise ConflictError(f"Ya existe un horario en {start.isoformat()}")
        return [self._slots.add(Slot(staff_user_id=staff_id, start_at=s)) for s in unique]

    def list_free(self, start: datetime | None, end: datetime | None,
                  staff_user_id: int | None) -> list[Slot]:
        now = self._clock()
        start = max(start, now) if start else now
        end = end or (now + timedelta(days=14))
        if end <= start:
            raise ValidationError("El rango de fechas no es válido")
        if end - start > timedelta(days=60):
            raise ValidationError("El rango máximo es de 60 días")
        return self._slots.list_free(start, end, staff_user_id)


class AppointmentService:
    def __init__(self, slots: SlotRepository, appointments: AppointmentRepository,
                 predictor: NoShowPredictor, clock: Clock = utc_now):
        self._slots = slots
        self._apps = appointments
        self._predictor = predictor
        self._clock = clock

    # ---- helpers -------------------------------------------------------
    def _get_visible(self, appointment_id: int, actor_id: int, actor_role: str) -> Appointment:
        appt = self._apps.get(appointment_id)
        if appt is None:
            raise NotFoundError("Cita no encontrada")
        if actor_role == Role.ESTUDIANTE.value and appt.student_user_id != actor_id:
            raise NotFoundError("Cita no encontrada")   # no revela que existe
        if actor_role == Role.PERSONAL_UNAYOE.value and appt.staff_user_id != actor_id:
            raise ForbiddenError("Esta cita pertenece a otro personal de UNAYOE")
        return appt

    def _check_student_can_change(self, appt: Appointment, actor_role: str) -> None:
        if not appt.is_active:
            raise ConflictError("La cita ya no está activa")
        if actor_role == Role.ESTUDIANTE.value:
            if appt.start_at - self._clock() < timedelta(hours=MIN_HOURS_TO_CHANGE):
                raise ConflictError(
                    f"Solo se puede modificar con al menos {MIN_HOURS_TO_CHANGE} horas de anticipación")

    # ---- casos de uso --------------------------------------------------
    def request(self, student_id: int, slot_id: int, priority: str | None,
                reason: str | None) -> Appointment:
        try:
            prio = Priority(priority or Priority.NORMAL.value)
        except ValueError:
            raise ValidationError("priority debe ser NORMAL o ALTA")
        if reason is not None:
            reason = reason.strip() or None
        if reason and len(reason) > MAX_REASON_LENGTH:
            raise ValidationError(f"reason admite hasta {MAX_REASON_LENGTH} caracteres")

        slot = self._slots.get(slot_id)
        if slot is None:
            raise NotFoundError("Horario no encontrado")
        now = self._clock()
        if slot.start_at <= now:
            raise ConflictError("El horario ya pasó")
        if self._apps.count_active(student_id) >= MAX_ACTIVE_APPOINTMENTS:
            raise ConflictError(f"Ya tienes {MAX_ACTIVE_APPOINTMENTS} citas activas")
        if not self._slots.reserve(slot_id):
            raise ConflictError("El horario ya no está disponible")
        try:
            appt = self._apps.add(Appointment(
                student_user_id=student_id, staff_user_id=slot.staff_user_id, slot_id=slot_id,
                start_at=slot.start_at, priority=prio, reason=reason,
                created_at=now, updated_at=now))
            self._apps.add_event(appt.id, "SOLICITADA", student_id, now)
        except Exception:
            self._slots.release(slot_id)   # sin transacción entre repos: compensación manual
            raise
        return appt

    def list_mine(self, student_id: int) -> list[Appointment]:
        return self._apps.list_for_student(student_id)

    def agenda(self, actor_id: int, actor_role: str, status: str | None,
               start: datetime | None, end: datetime | None) -> list[Appointment]:
        if status is not None and status not in {s.value for s in AppointmentStatus}:
            raise ValidationError("status no es válido")
        staff_filter = actor_id if actor_role == Role.PERSONAL_UNAYOE.value else None
        return self._apps.list_agenda(staff_filter, status, start, end)

    def cancel(self, appointment_id: int, actor_id: int, actor_role: str,
               reason: str | None) -> Appointment:
        appt = self._get_visible(appointment_id, actor_id, actor_role)
        self._check_student_can_change(appt, actor_role)
        now = self._clock()
        appt.status = AppointmentStatus.CANCELADA
        appt.cancelled_by = actor_id
        appt.cancel_reason = (reason or "").strip()[:MAX_REASON_LENGTH] or None
        appt.updated_at = now
        self._apps.update(appt)
        self._slots.release(appt.slot_id)
        self._apps.add_event(appt.id, "CANCELADA", actor_id, now)
        return appt

    def reschedule(self, appointment_id: int, actor_id: int, actor_role: str,
                   new_slot_id: int) -> Appointment:
        appt = self._get_visible(appointment_id, actor_id, actor_role)
        if actor_role != Role.ESTUDIANTE.value:
            raise ForbiddenError("Solo el estudiante puede reprogramar su cita")
        self._check_student_can_change(appt, actor_role)
        new_slot = self._slots.get(new_slot_id)
        if new_slot is None:
            raise NotFoundError("Horario no encontrado")
        now = self._clock()
        if new_slot.start_at <= now:
            raise ConflictError("El horario ya pasó")
        if new_slot.id == appt.slot_id:
            raise ValidationError("Elige un horario distinto al actual")
        if not self._slots.reserve(new_slot_id):
            raise ConflictError("El horario ya no está disponible")
        old_slot_id = appt.slot_id
        appt.slot_id, appt.staff_user_id, appt.start_at = new_slot.id, new_slot.staff_user_id, new_slot.start_at
        appt.status = AppointmentStatus.SOLICITADA
        appt.reschedule_count += 1
        appt.updated_at = now
        try:
            self._apps.update(appt)
        except Exception:
            self._slots.release(new_slot_id)
            raise
        self._slots.release(old_slot_id)
        self._apps.add_event(appt.id, "REPROGRAMADA", actor_id, now)
        return appt

    def change_status(self, appointment_id: int, actor_id: int, actor_role: str,
                      new_status: str) -> Appointment:
        if not _is_staff(actor_role):
            raise ForbiddenError("No tienes permisos para realizar esta operación")
        appt = self._get_visible(appointment_id, actor_id, actor_role)
        try:
            target = AppointmentStatus(new_status)
        except ValueError:
            raise ValidationError("status no es válido")
        if target not in ALLOWED_TRANSITIONS.get(appt.status, ()):
            raise ConflictError(f"No se puede pasar de {appt.status.value} a {target.value}")
        now = self._clock()
        if target in (AppointmentStatus.ATENDIDA, AppointmentStatus.NO_ASISTIO) and now < appt.start_at:
            raise ConflictError("La cita todavía no ocurrió")
        appt.status = target
        appt.updated_at = now
        self._apps.update(appt)
        self._apps.add_event(appt.id, target.value, actor_id, now)
        return appt

    def no_show_risk(self, appointment_id: int, actor_id: int, actor_role: str) -> dict:
        if not _is_staff(actor_role):
            raise ForbiddenError("No tienes permisos para realizar esta operación")
        appt = self._get_visible(appointment_id, actor_id, actor_role)
        features = {
            "lead_days": max((appt.start_at - appt.created_at).total_seconds() / 86400, 0),
            "hour_local": (appt.start_at - timedelta(hours=5)).hour,   # America/Lima (UTC-5)
            "prior_no_shows": self._apps.count_by_status(
                appt.student_user_id, AppointmentStatus.NO_ASISTIO.value),
            "prior_cancellations": self._apps.count_by_status(
                appt.student_user_id, AppointmentStatus.CANCELADA.value),
            "reschedule_count": appt.reschedule_count,
        }
        result = self._predictor.predict(features)
        return {"appointmentId": appt.id, "noShowProbability": result["probability"],
                "factors": result["factors"], "model": result["model"],
                "note": "Orientativo: solo sirve para decidir recordatorios; nunca para negar o retrasar una cita."}

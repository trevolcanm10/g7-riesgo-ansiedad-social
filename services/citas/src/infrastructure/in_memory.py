"""Repositorios en memoria: para pruebas y para ensayar sin MySQL (USE_IN_MEMORY=true)."""
import copy
import threading
from datetime import datetime

from src.domain.model import ACTIVE_STATUSES, Appointment, Slot, SlotStatus
from src.domain.ports import AppointmentRepository, SlotRepository


class InMemorySlotRepository(SlotRepository):
    def __init__(self):
        self._items: dict[int, Slot] = {}
        self._seq = 0
        self._lock = threading.Lock()

    def add(self, slot):
        with self._lock:
            self._seq += 1
            slot.id = self._seq
            self._items[slot.id] = copy.copy(slot)
            return copy.copy(slot)

    def get(self, slot_id):
        s = self._items.get(slot_id)
        return copy.copy(s) if s else None

    def list_free(self, start, end, staff_user_id):
        return sorted(
            (copy.copy(s) for s in self._items.values()
             if s.status == SlotStatus.LIBRE and start <= s.start_at < end
             and (staff_user_id is None or s.staff_user_id == staff_user_id)),
            key=lambda s: s.start_at)

    def exists(self, staff_user_id, start_at):
        return any(s.staff_user_id == staff_user_id and s.start_at == start_at
                   for s in self._items.values())

    def reserve(self, slot_id):
        with self._lock:
            s = self._items.get(slot_id)
            if s is None or s.status != SlotStatus.LIBRE:
                return False
            s.status = SlotStatus.RESERVADO
            return True

    def release(self, slot_id):
        with self._lock:
            s = self._items.get(slot_id)
            if s is not None and s.status == SlotStatus.RESERVADO:
                s.status = SlotStatus.LIBRE


class InMemoryAppointmentRepository(AppointmentRepository):
    def __init__(self):
        self._items: dict[int, Appointment] = {}
        self.events: list[tuple] = []
        self._seq = 0
        self._lock = threading.Lock()

    def add(self, appointment):
        with self._lock:
            self._seq += 1
            appointment.id = self._seq
            self._items[appointment.id] = copy.copy(appointment)
            return copy.copy(appointment)

    def get(self, appointment_id):
        a = self._items.get(appointment_id)
        return copy.copy(a) if a else None

    def update(self, appointment):
        self._items[appointment.id] = copy.copy(appointment)

    def list_for_student(self, student_user_id):
        return sorted((copy.copy(a) for a in self._items.values()
                       if a.student_user_id == student_user_id), key=lambda a: a.start_at)

    def list_agenda(self, staff_user_id, status, start, end):
        return sorted(
            (copy.copy(a) for a in self._items.values()
             if (staff_user_id is None or a.staff_user_id == staff_user_id)
             and (status is None or a.status.value == status)
             and (start is None or a.start_at >= start)
             and (end is None or a.start_at < end)),
            key=lambda a: a.start_at)

    def count_active(self, student_user_id):
        return sum(1 for a in self._items.values()
                   if a.student_user_id == student_user_id and a.status in ACTIVE_STATUSES)

    def count_by_status(self, student_user_id, status):
        return sum(1 for a in self._items.values()
                   if a.student_user_id == student_user_id and a.status.value == status)

    def add_event(self, appointment_id, event_type, actor_user_id, created_at):
        self.events.append((appointment_id, event_type, actor_user_id, created_at))

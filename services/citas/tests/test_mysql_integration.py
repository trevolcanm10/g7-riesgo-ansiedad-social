"""Pruebas de integración contra MySQL real (opcionales).

Se omiten salvo que definas TEST_DB_NAME. Usa una base APARTE: estas pruebas
BORRAN el contenido de las tablas de Citas. Por seguridad, TEST_DB_NAME debe
terminar en "_test".

Variables (en services/citas/.env o en el entorno):
    TEST_DB_HOST (def. localhost)  TEST_DB_PORT (def. 3306)
    TEST_DB_NAME (obligatoria, termina en _test)
    TEST_DB_USER  TEST_DB_PASSWORD  TEST_DB_SSL (def. false)

Ejecutar desde services/citas:
    python -m unittest tests.test_mysql_integration -v
"""
import os
import threading
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pymysql

from src.config import settings  # noqa: F401  (carga el .env)
from src.domain.errors import ConflictError
from src.domain.model import (
    Appointment, AppointmentStatus, Priority, Slot, SlotStatus,
)
from tests import test_citas_api as base

NAME = os.environ.get("TEST_DB_NAME", "")
CFG = dict(
    host=os.environ.get("TEST_DB_HOST", "localhost"),
    port=int(os.environ.get("TEST_DB_PORT", "3306")),
    user=os.environ.get("TEST_DB_USER", ""),
    password=os.environ.get("TEST_DB_PASSWORD", ""),
)
SSL = os.environ.get("TEST_DB_SSL", "false").strip().lower() in ("1", "true", "yes")
SCHEMA = Path(__file__).resolve().parents[1] / "db" / "schema.sql"
TABLES = ("appointment_events", "appointments", "availability_slots")   # orden por FK

ENABLED = bool(NAME)
if ENABLED and not NAME.endswith("_test"):
    raise RuntimeError("TEST_DB_NAME debe terminar en '_test' (estas pruebas borran datos)")


def _db():
    from src.infrastructure.mysql_repositories import Database
    return Database(CFG["host"], CFG["port"], NAME, CFG["user"], CFG["password"], SSL)


def _raw(cursor_class=pymysql.cursors.Cursor):
    return pymysql.connect(database=NAME, autocommit=True, charset="utf8mb4",
                           cursorclass=cursor_class, **CFG)


def _apply_schema_and_clean():
    sql = SCHEMA.read_text(encoding="utf-8")
    statements = [s.strip() for s in "\n".join(
        line for line in sql.splitlines() if not line.strip().startswith("--")).split(";")
        if s.strip()]
    conn = _raw()
    try:
        with conn.cursor() as cur:
            for stmt in statements:
                cur.execute(stmt)
            for table in TABLES:
                cur.execute(f"DELETE FROM {table}")
    finally:
        conn.close()


@unittest.skipUnless(ENABLED, "Define TEST_DB_NAME (base *_test) para correr contra MySQL")
class MySqlApiTest(base.CitasApiTest):
    """Las mismas pruebas de la API, pero con los repositorios MySQL."""

    def make_repos(self):
        from src.infrastructure.mysql_repositories import (
            MySqlAppointmentRepository, MySqlSlotRepository,
        )
        _apply_schema_and_clean()
        db = _db()
        return MySqlSlotRepository(db), MySqlAppointmentRepository(db)


@unittest.skipUnless(ENABLED, "Define TEST_DB_NAME (base *_test) para correr contra MySQL")
class MySqlRepositoryTest(unittest.TestCase):
    """Comportamientos propios de la base: concurrencia, restricciones y fechas."""

    def setUp(self):
        from src.infrastructure.mysql_repositories import (
            MySqlAppointmentRepository, MySqlSlotRepository,
        )
        _apply_schema_and_clean()
        self.db = _db()
        self.slots = MySqlSlotRepository(self.db)
        self.apps = MySqlAppointmentRepository(self.db)
        self.t0 = datetime(2030, 1, 15, 15, 0, tzinfo=timezone.utc)

    def test_ping(self):
        self.assertTrue(self.db.ping())

    def test_slot_roundtrip_keeps_utc(self):
        s = self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        got = self.slots.get(s.id)
        self.assertEqual(got.start_at, self.t0)
        self.assertEqual(got.start_at.utcoffset(), timedelta(0))
        self.assertEqual(got.status, SlotStatus.LIBRE)

    def test_unique_slot_per_staff_and_start(self):
        self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        with self.assertRaises(ConflictError):          # la restricción única se traduce a 409
            self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        self.slots.add(Slot(staff_user_id=11, start_at=self.t0))   # otro personal: permitido
        self.assertTrue(self.slots.exists(10, self.t0))
        self.assertFalse(self.slots.exists(12, self.t0))

    def test_add_many_is_all_or_nothing(self):
        self.slots.add(Slot(staff_user_id=10, start_at=self.t0 + timedelta(minutes=30)))
        batch = [Slot(staff_user_id=10, start_at=self.t0),
                 Slot(staff_user_id=10, start_at=self.t0 + timedelta(minutes=30))]   # el 2.º choca
        with self.assertRaises(ConflictError):
            self.slots.add_many(batch)
        self.assertFalse(self.slots.exists(10, self.t0), "el 1.º no debe quedar creado")

    def test_concurrent_publish_gives_conflict_not_500(self):
        outcomes, barrier = [], threading.Barrier(6)

        def worker():
            barrier.wait()
            try:
                self.slots.add_many([Slot(staff_user_id=10, start_at=self.t0)])
                outcomes.append("ok")
            except ConflictError:
                outcomes.append("conflicto")

        threads = [threading.Thread(target=worker) for _ in range(6)]
        [t.start() for t in threads]
        [t.join() for t in threads]
        self.assertEqual(sorted(outcomes), ["conflicto"] * 5 + ["ok"])

    def test_optimistic_update_rejects_stale_writes(self):
        a = self._appt(student=1)
        stale = self.apps.get(a.id)
        winner = self.apps.get(a.id)
        winner.status = AppointmentStatus.CANCELADA
        self.assertTrue(self.apps.update(winner, expect_status=AppointmentStatus.SOLICITADA))
        stale.status = AppointmentStatus.CONFIRMADA
        self.assertFalse(self.apps.update(stale, expect_status=AppointmentStatus.SOLICITADA))
        self.assertEqual(self.apps.get(a.id).status, AppointmentStatus.CANCELADA)
        # también protege contra un cambio de horario concurrente
        other = self.slots.add(Slot(staff_user_id=10, start_at=self.t0 + timedelta(hours=5)))
        moved = self.apps.get(a.id)
        moved.slot_id = other.id
        self.assertFalse(self.apps.update(moved, expect_slot_id=a.slot_id + 999))

    def test_count_by_status_before_and_exclude(self):
        first = self._appt(student=1, status=AppointmentStatus.NO_ASISTIO)
        later = self.slots.add(Slot(staff_user_id=10, start_at=self.t0 + timedelta(days=3)))
        second = self._appt(student=1, slot=later, status=AppointmentStatus.NO_ASISTIO)
        self.assertEqual(self.apps.count_by_status(1, "NO_ASISTIO"), 2)
        self.assertEqual(self.apps.count_by_status(1, "NO_ASISTIO", before=second.start_at), 1)
        self.assertEqual(self.apps.count_by_status(
            1, "NO_ASISTIO", before=second.start_at, exclude_id=first.id), 0)

    def test_reserve_is_atomic_under_concurrency(self):
        slot = self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        results, barrier = [], threading.Barrier(8)

        def worker():
            barrier.wait()
            results.append(self.slots.reserve(slot.id))

        threads = [threading.Thread(target=worker) for _ in range(8)]
        [t.start() for t in threads]
        [t.join() for t in threads]
        self.assertEqual(results.count(True), 1, results)
        self.assertEqual(self.slots.get(slot.id).status, SlotStatus.RESERVADO)

    def test_release_only_from_reserved(self):
        slot = self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        self.slots.release(slot.id)                     # ya libre: sin efecto
        self.assertTrue(self.slots.reserve(slot.id))
        self.slots.release(slot.id)
        self.assertEqual(self.slots.get(slot.id).status, SlotStatus.LIBRE)

    def test_list_free_range_and_filters(self):
        a = self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        b = self.slots.add(Slot(staff_user_id=11, start_at=self.t0 + timedelta(minutes=30)))
        self.slots.reserve(a.id)
        free = self.slots.list_free(self.t0, self.t0 + timedelta(hours=2), None)
        self.assertEqual([s.id for s in free], [b.id])
        self.assertEqual(self.slots.list_free(self.t0, self.t0 + timedelta(hours=2), 10), [])
        # el extremo final es exclusivo
        self.assertEqual(self.slots.list_free(self.t0, b.start_at, None), [])

    def _appt(self, student=1, slot=None, status=AppointmentStatus.SOLICITADA, **kw):
        slot = slot or self.slots.add(Slot(staff_user_id=10,
                                           start_at=self.t0 + timedelta(minutes=30 * student)))
        now = datetime(2030, 1, 1, 12, 0, tzinfo=timezone.utc)
        return self.apps.add(Appointment(
            student_user_id=student, staff_user_id=slot.staff_user_id, slot_id=slot.id,
            start_at=slot.start_at, status=status, priority=kw.get("priority", Priority.NORMAL),
            reason=kw.get("reason"), created_at=now, updated_at=now))

    def test_appointment_roundtrip_update_and_counts(self):
        a = self._appt(student=1, priority=Priority.ALTA, reason="Ansiedad")
        got = self.apps.get(a.id)
        self.assertEqual((got.priority, got.reason, got.status),
                         (Priority.ALTA, "Ansiedad", AppointmentStatus.SOLICITADA))
        got.status = AppointmentStatus.CANCELADA
        got.cancelled_by, got.cancel_reason = 10, "Cambio de turno"
        got.updated_at = got.updated_at + timedelta(hours=1)
        self.apps.update(got)
        again = self.apps.get(a.id)
        self.assertEqual((again.status, again.cancelled_by, again.cancel_reason),
                         (AppointmentStatus.CANCELADA, 10, "Cambio de turno"))
        self.assertEqual(self.apps.count_active(1), 0)
        self.assertEqual(self.apps.count_by_status(1, "CANCELADA"), 1)

    def test_count_active_and_agenda_filters(self):
        self._appt(student=1)
        self._appt(student=2, status=AppointmentStatus.CONFIRMADA)
        self._appt(student=3, status=AppointmentStatus.ATENDIDA)
        self.assertEqual(self.apps.count_active(2), 1)
        self.assertEqual(self.apps.count_active(3), 0)
        self.assertEqual(len(self.apps.list_agenda(10, None, None, None)), 3)
        self.assertEqual(len(self.apps.list_agenda(99, None, None, None)), 0)
        self.assertEqual(len(self.apps.list_agenda(None, "CONFIRMADA", None, None)), 1)
        self.assertEqual(len(self.apps.list_for_student(1)), 1)

    def test_events_require_existing_appointment(self):
        a = self._appt()
        self.apps.add_event(a.id, "SOLICITADA", 1, a.created_at)
        with _raw() as conn, conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM appointment_events WHERE appointment_id=%s", (a.id,))
            self.assertEqual(cur.fetchone()[0], 1)
        with self.assertRaises(pymysql.err.IntegrityError):
            self.apps.add_event(999999, "X", 1, a.created_at)

    def test_fractional_seconds_are_not_rounded_up(self):
        """DATETIME(0) redondea los microsegundos; una marca 12:00:59.7 no debe pasar a 12:01."""
        now = datetime(2030, 1, 1, 12, 0, 59, 700000, tzinfo=timezone.utc)
        slot = self.slots.add(Slot(staff_user_id=10, start_at=self.t0))
        a = self.apps.add(Appointment(
            student_user_id=1, staff_user_id=10, slot_id=slot.id, start_at=slot.start_at,
            priority=Priority.NORMAL, reason=None, created_at=now, updated_at=now))
        got = self.apps.get(a.id)
        self.assertEqual(got.created_at, now.replace(microsecond=0))


if __name__ == "__main__":
    unittest.main()

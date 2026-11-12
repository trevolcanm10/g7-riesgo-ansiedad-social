"""Repositorios MySQL (PyMySQL). Una conexión corta por operación: simple y suficiente para el MVP."""
from contextlib import contextmanager
from datetime import datetime, timezone

import pymysql
from pymysql.cursors import DictCursor

from src.domain.errors import ConflictError
from src.domain.model import (
    ACTIVE_STATUSES, Appointment, AppointmentStatus, Priority, Slot, SlotStatus,
)
from src.domain.ports import AppointmentRepository, SlotRepository


class Database:
    def __init__(self, host, port, name, user, password, ssl=True):
        self._kwargs = dict(host=host, port=port, database=name, user=user, password=password,
                            charset="utf8mb4", cursorclass=DictCursor, autocommit=True,
                            connect_timeout=10)
        if ssl:   # mismo criterio que los servicios Node: TLS sin verificar el certificado
            self._kwargs.update(ssl={"fake_flag_to_enable_tls": True},
                                ssl_verify_cert=False, ssl_verify_identity=False)

    @contextmanager
    def cursor(self):
        conn = pymysql.connect(**self._kwargs)
        try:
            with conn.cursor() as cur:
                yield cur
        finally:
            conn.close()

    @contextmanager
    def transaction(self):
        """Cursor dentro de una transacción: confirma al salir o deshace si hay error."""
        conn = pymysql.connect(**{**self._kwargs, "autocommit": False})
        try:
            with conn.cursor() as cur:
                yield cur
            conn.commit()
        except Exception:
            conn.rollback()
            raise
        finally:
            conn.close()

    def ping(self) -> bool:
        try:
            with self.cursor() as cur:
                cur.execute("SELECT 1")
            return True
        except Exception:
            return False


def _to_db(dt: datetime) -> datetime:
    # DATETIME(0) redondea los microsegundos hacia arriba (12:00:59.7 -> 12:01:00):
    # se truncan para que ninguna marca de tiempo se adelante.
    return dt.astimezone(timezone.utc).replace(tzinfo=None, microsecond=0)


def _from_db(dt: datetime) -> datetime:
    return dt.replace(tzinfo=timezone.utc)


def _slot(row) -> Slot:
    return Slot(id=row["id"], staff_user_id=row["staff_user_id"],
                start_at=_from_db(row["start_at"]), status=SlotStatus(row["status"]))


def _appt(row) -> Appointment:
    return Appointment(
        id=row["id"], student_user_id=row["student_user_id"], staff_user_id=row["staff_user_id"],
        slot_id=row["slot_id"], start_at=_from_db(row["start_at"]),
        status=AppointmentStatus(row["status"]), priority=Priority(row["priority"]),
        reason=row["reason"], reschedule_count=row["reschedule_count"],
        cancelled_by=row["cancelled_by"], cancel_reason=row["cancel_reason"],
        created_at=_from_db(row["created_at"]), updated_at=_from_db(row["updated_at"]))


class MySqlSlotRepository(SlotRepository):
    def __init__(self, db: Database):
        self._db = db

    _INSERT = ("INSERT INTO availability_slots (staff_user_id, start_at, status) "
               "VALUES (%s, %s, %s)")

    def add(self, slot):
        return self.add_many([slot])[0]

    def add_many(self, slots):
        # Una sola transacción: o se crean todos o ninguno. Si dos solicitudes publican el mismo
        # horario a la vez, la restricción única de MySQL rechaza a la segunda -> 409, no 500.
        try:
            with self._db.transaction() as cur:
                for slot in slots:
                    cur.execute(self._INSERT, (slot.staff_user_id, _to_db(slot.start_at),
                                               slot.status.value))
                    slot.id = cur.lastrowid
        except pymysql.err.IntegrityError as exc:
            raise ConflictError("Alguno de los horarios ya existe") from exc
        return slots

    def get(self, slot_id):
        with self._db.cursor() as cur:
            cur.execute("SELECT * FROM availability_slots WHERE id = %s", (slot_id,))
            row = cur.fetchone()
        return _slot(row) if row else None

    def list_free(self, start, end, staff_user_id):
        sql = ("SELECT * FROM availability_slots WHERE status = 'LIBRE' "
               "AND start_at >= %s AND start_at < %s")
        params = [_to_db(start), _to_db(end)]
        if staff_user_id is not None:
            sql += " AND staff_user_id = %s"
            params.append(staff_user_id)
        with self._db.cursor() as cur:
            cur.execute(sql + " ORDER BY start_at", params)
            return [_slot(r) for r in cur.fetchall()]

    def list_for_staff(self, staff_user_id, after, before):
        with self._db.cursor() as cur:
            cur.execute("SELECT * FROM availability_slots WHERE staff_user_id = %s "
                        "AND start_at > %s AND start_at < %s ORDER BY start_at",
                        (staff_user_id, _to_db(after), _to_db(before)))
            return [_slot(r) for r in cur.fetchall()]

    def reserve(self, slot_id):
        # UPDATE condicional: evita doble reserva aunque dos solicitudes lleguen a la vez.
        with self._db.cursor() as cur:
            cur.execute("UPDATE availability_slots SET status = 'RESERVADO' "
                        "WHERE id = %s AND status = 'LIBRE'", (slot_id,))
            return cur.rowcount == 1

    def release(self, slot_id):
        with self._db.cursor() as cur:
            cur.execute("UPDATE availability_slots SET status = 'LIBRE' "
                        "WHERE id = %s AND status = 'RESERVADO'", (slot_id,))


class MySqlAppointmentRepository(AppointmentRepository):
    def __init__(self, db: Database):
        self._db = db

    def add(self, a):
        with self._db.cursor() as cur:
            cur.execute(
                "INSERT INTO appointments (student_user_id, staff_user_id, slot_id, start_at, status, "
                "priority, reason, reschedule_count, created_at, updated_at) "
                "VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                (a.student_user_id, a.staff_user_id, a.slot_id, _to_db(a.start_at), a.status.value,
                 a.priority.value, a.reason, a.reschedule_count, _to_db(a.created_at),
                 _to_db(a.updated_at)))
            a.id = cur.lastrowid
        return a

    def get(self, appointment_id):
        with self._db.cursor() as cur:
            cur.execute("SELECT * FROM appointments WHERE id = %s", (appointment_id,))
            row = cur.fetchone()
        return _appt(row) if row else None

    def update(self, a, *, expect_status=None, expect_slot_id=None):
        sql = ("UPDATE appointments SET staff_user_id=%s, slot_id=%s, start_at=%s, status=%s, "
               "reschedule_count=%s, cancelled_by=%s, cancel_reason=%s, updated_at=%s WHERE id=%s")
        params = [a.staff_user_id, a.slot_id, _to_db(a.start_at), a.status.value, a.reschedule_count,
                  a.cancelled_by, a.cancel_reason, _to_db(a.updated_at), a.id]
        if expect_status is not None:       # bloqueo optimista
            sql += " AND status = %s"
            params.append(expect_status.value)
        if expect_slot_id is not None:
            sql += " AND slot_id = %s"
            params.append(expect_slot_id)
        with self._db.cursor() as cur:
            cur.execute(sql, params)
            return cur.rowcount == 1

    def list_for_student(self, student_user_id):
        with self._db.cursor() as cur:
            cur.execute("SELECT * FROM appointments WHERE student_user_id = %s ORDER BY start_at",
                        (student_user_id,))
            return [_appt(r) for r in cur.fetchall()]

    def list_agenda(self, staff_user_id, status, start, end):
        sql, params = "SELECT * FROM appointments WHERE 1=1", []
        if staff_user_id is not None:
            sql += " AND staff_user_id = %s"; params.append(staff_user_id)
        if status is not None:
            sql += " AND status = %s"; params.append(status)
        if start is not None:
            sql += " AND start_at >= %s"; params.append(_to_db(start))
        if end is not None:
            sql += " AND start_at < %s"; params.append(_to_db(end))
        with self._db.cursor() as cur:
            cur.execute(sql + " ORDER BY start_at", params)
            return [_appt(r) for r in cur.fetchall()]

    def count_active(self, student_user_id):
        marks = ",".join(["%s"] * len(ACTIVE_STATUSES))
        with self._db.cursor() as cur:
            cur.execute(f"SELECT COUNT(*) AS n FROM appointments WHERE student_user_id = %s "
                        f"AND status IN ({marks})",
                        (student_user_id, *[s.value for s in ACTIVE_STATUSES]))
            return cur.fetchone()["n"]

    def count_by_status(self, student_user_id, status, *, before=None, exclude_id=None):
        sql = "SELECT COUNT(*) AS n FROM appointments WHERE student_user_id = %s AND status = %s"
        params = [student_user_id, status]
        if before is not None:
            sql += " AND start_at < %s"
            params.append(_to_db(before))
        if exclude_id is not None:
            sql += " AND id <> %s"
            params.append(exclude_id)
        with self._db.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchone()["n"]

    def add_event(self, appointment_id, event_type, actor_user_id, created_at):
        with self._db.cursor() as cur:
            cur.execute("INSERT INTO appointment_events (appointment_id, event_type, actor_user_id, "
                        "created_at) VALUES (%s,%s,%s,%s)",
                        (appointment_id, event_type, actor_user_id, _to_db(created_at)))

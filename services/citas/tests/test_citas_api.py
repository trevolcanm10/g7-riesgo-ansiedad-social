import time
import unittest
from datetime import datetime, timedelta, timezone

import jwt

from src.application.services import AppointmentService, SlotService
from src.domain.model import AppointmentStatus
from src.domain.ports import NoShowPredictor
from src.infrastructure.in_memory import InMemoryAppointmentRepository, InMemorySlotRepository
from src.infrastructure.jwt_token_service import JwtTokenService
from src.infrastructure.rule_based_no_show import RuleBasedNoShowPredictor
from src.presentation.http import create_http_app

SECRET = "secreto-de-pruebas"
NOW = datetime(2026, 11, 10, 15, 0, tzinfo=timezone.utc)


def token(user_id, role, secret=SECRET, exp=3600):
    return jwt.encode({"userId": user_id, "role": role, "exp": int(time.time()) + exp},
                      secret, algorithm="HS256")


def auth(user_id, role):
    return {"Authorization": f"Bearer {token(user_id, role)}"}


def iso(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


class CitasApiTest(unittest.TestCase):
    def make_repos(self):
        """Repositorios a probar. test_mysql_integration los sustituye por los de MySQL."""
        return InMemorySlotRepository(), InMemoryAppointmentRepository()

    def setUp(self):
        self.now = NOW
        clock = lambda: self.now
        self.slots_repo, self.apps_repo = self.make_repos()
        self.app = create_http_app(
            SlotService(self.slots_repo, clock),
            AppointmentService(self.slots_repo, self.apps_repo, RuleBasedNoShowPredictor(), clock),
            JwtTokenService(SECRET), lambda: True)
        self.c = self.app.test_client()
        self.staff = auth(10, "PERSONAL_UNAYOE")
        self.student = auth(1, "ESTUDIANTE")

    def publish(self, *hours_ahead, headers=None):
        starts = [iso(self.now + timedelta(hours=h)) for h in hours_ahead]
        r = self.c.post("/slots", json={"startAts": starts}, headers=headers or self.staff)
        self.assertEqual(r.status_code, 201, r.get_json())
        return r.get_json()

    def book(self, slot_id, headers=None, **extra):
        return self.c.post("/appointments", json={"slotId": slot_id, **extra},
                           headers=headers or self.student)

    # ---------- salud y autenticación ----------
    def test_health_ok(self):
        r = self.c.get("/health")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.get_json()["service"], "citas")
        self.assertEqual(r.get_json()["noShowModel"], "rule-based-baseline-v0")

    def test_requires_token(self):
        self.assertEqual(self.c.get("/slots").status_code, 401)
        r = self.c.get("/slots", headers={"Authorization": "Bearer basura"})
        self.assertEqual(r.status_code, 401)
        bad = {"Authorization": f"Bearer {token(1, 'ESTUDIANTE', secret='otro')}"}
        self.assertEqual(self.c.get("/slots", headers=bad).status_code, 401)

    def test_role_enforcement(self):
        r = self.c.post("/slots", json={"startAts": []}, headers=self.student)
        self.assertEqual(r.status_code, 403)
        self.assertEqual(self.c.get("/appointments", headers=self.student).status_code, 403)
        self.assertEqual(self.c.get("/appointments/me", headers=self.staff).status_code, 403)

    # ---------- horarios ----------
    def test_publish_and_list_slots(self):
        created = self.publish(48, 49)
        self.assertEqual(len(created), 2)
        self.assertEqual(created[0]["staffUserId"], 10)
        free = self.c.get("/slots", headers=self.student).get_json()
        self.assertEqual(len(free), 2)
        # 30 minutos fijos
        start = datetime.fromisoformat(free[0]["startAt"].replace("Z", "+00:00"))
        end = datetime.fromisoformat(free[0]["endAt"].replace("Z", "+00:00"))
        self.assertEqual(end - start, timedelta(minutes=30))

    def test_publish_validations(self):
        past = self.c.post("/slots", json={"startAts": [iso(self.now - timedelta(hours=1))]},
                           headers=self.staff)
        self.assertEqual(past.status_code, 400)
        naive = self.c.post("/slots", json={"startAts": ["2026-12-01T10:00:00"]}, headers=self.staff)
        self.assertEqual(naive.status_code, 400)
        self.publish(48)
        dup = self.c.post("/slots", json={"startAts": [iso(self.now + timedelta(hours=48))]},
                          headers=self.staff)
        self.assertEqual(dup.status_code, 409)
        admin_no_staff = self.c.post("/slots", json={"startAts": [iso(self.now + timedelta(hours=60))]},
                                     headers=auth(99, "ADMINISTRADOR"))
        self.assertEqual(admin_no_staff.status_code, 400)

    # ---------- citas ----------
    def test_book_and_list_mine(self):
        slot = self.publish(48)[0]
        r = self.book(slot["id"], priority="ALTA", reason="  Me siento ansioso  ")
        self.assertEqual(r.status_code, 201, r.get_json())
        appt = r.get_json()
        self.assertEqual(appt["status"], "SOLICITADA")
        self.assertEqual(appt["priority"], "ALTA")
        self.assertEqual(appt["reason"], "Me siento ansioso")
        self.assertEqual(appt["studentUserId"], 1)
        self.assertEqual(len(self.c.get("/appointments/me", headers=self.student).get_json()), 1)
        self.assertEqual(self.c.get("/slots", headers=self.student).get_json(), [])

    def test_no_double_booking(self):
        slot = self.publish(48)[0]
        self.assertEqual(self.book(slot["id"]).status_code, 201)
        r = self.book(slot["id"], headers=auth(2, "ESTUDIANTE"))
        self.assertEqual(r.status_code, 409)

    def test_max_two_active(self):
        ids = [s["id"] for s in self.publish(48, 49, 50)]
        self.assertEqual(self.book(ids[0]).status_code, 201)
        self.assertEqual(self.book(ids[1]).status_code, 201)
        self.assertEqual(self.book(ids[2]).status_code, 409)

    def test_book_validations(self):
        slot = self.publish(48)[0]
        self.assertEqual(self.book(slot["id"], priority="URGENTE").status_code, 400)
        self.assertEqual(self.book(9999).status_code, 404)
        self.assertEqual(self.book("x").status_code, 400)

    def test_cancel_frees_slot_and_respects_notice(self):
        near, far = self.publish(6, 48)   # publish devuelve los horarios ordenados
        a_far = self.book(far["id"]).get_json()
        r = self.c.patch(f"/appointments/{a_far['id']}/cancel", json={"reason": "examen"},
                         headers=self.student)
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.get_json()["status"], "CANCELADA")
        self.assertEqual(len(self.c.get("/slots", headers=self.student).get_json()), 2)  # far liberado + near
        a_near = self.book(near["id"]).get_json()
        late = self.c.patch(f"/appointments/{a_near['id']}/cancel", json={}, headers=self.student)
        self.assertEqual(late.status_code, 409)   # < 12 h
        by_staff = self.c.patch(f"/appointments/{a_near['id']}/cancel", json={}, headers=self.staff)
        self.assertEqual(by_staff.status_code, 200)  # UNAYOE sí puede

    def test_other_student_cannot_see_or_cancel(self):
        slot = self.publish(48)[0]
        appt = self.book(slot["id"]).get_json()
        r = self.c.patch(f"/appointments/{appt['id']}/cancel", json={}, headers=auth(2, "ESTUDIANTE"))
        self.assertEqual(r.status_code, 404)

    def test_other_staff_cannot_touch(self):
        slot = self.publish(48)[0]
        appt = self.book(slot["id"]).get_json()
        r = self.c.patch(f"/appointments/{appt['id']}/status", json={"status": "CONFIRMADA"},
                         headers=auth(11, "PERSONAL_UNAYOE"))
        self.assertEqual(r.status_code, 403)
        admin = self.c.patch(f"/appointments/{appt['id']}/status", json={"status": "CONFIRMADA"},
                             headers=auth(99, "ADMINISTRADOR"))
        self.assertEqual(admin.status_code, 200)

    def test_reschedule(self):
        a, b = self.publish(48, 72)
        appt = self.book(a["id"]).get_json()
        r = self.c.patch(f"/appointments/{appt['id']}/reschedule", json={"slotId": b["id"]},
                         headers=self.student)
        self.assertEqual(r.status_code, 200, r.get_json())
        self.assertEqual(r.get_json()["slotId"], b["id"])
        self.assertEqual(r.get_json()["rescheduleCount"], 1)
        free_ids = [s["id"] for s in self.c.get("/slots", headers=self.student).get_json()]
        self.assertEqual(free_ids, [a["id"]])
        again = self.c.patch(f"/appointments/{appt['id']}/reschedule", json={"slotId": b["id"]},
                             headers=self.student)
        self.assertEqual(again.status_code, 400)   # mismo horario

    def test_status_flow(self):
        slot = self.publish(2)[0]
        appt = self.book(slot["id"]).get_json()
        path = f"/appointments/{appt['id']}/status"
        skip = self.c.patch(path, json={"status": "ATENDIDA"}, headers=self.staff)
        self.assertEqual(skip.status_code, 409)   # SOLICITADA -> ATENDIDA no permitido
        ok = self.c.patch(path, json={"status": "CONFIRMADA"}, headers=self.staff)
        self.assertEqual(ok.get_json()["status"], "CONFIRMADA")
        early = self.c.patch(path, json={"status": "NO_ASISTIO"}, headers=self.staff)
        self.assertEqual(early.status_code, 409)  # la cita aún no ocurrió
        self.now += timedelta(hours=3)
        done = self.c.patch(path, json={"status": "NO_ASISTIO"}, headers=self.staff)
        self.assertEqual(done.get_json()["status"], "NO_ASISTIO")
        self.assertEqual(self.c.patch(path, json={"status": "ATENDIDA"}, headers=self.staff).status_code, 409)
        self.assertEqual(self.c.patch(path, json={"status": "XYZ"}, headers=self.staff).status_code, 400)

    def test_agenda_filters_by_staff(self):
        slot = self.publish(48)[0]
        self.book(slot["id"])
        mine = self.c.get("/appointments", headers=self.staff).get_json()
        self.assertEqual(len(mine), 1)
        other = self.c.get("/appointments", headers=auth(11, "PERSONAL_UNAYOE")).get_json()
        self.assertEqual(other, [])
        admin = self.c.get("/appointments?status=SOLICITADA", headers=auth(99, "ADMINISTRADOR")).get_json()
        self.assertEqual(len(admin), 1)
        bad = self.c.get("/appointments?status=NOPE", headers=self.staff)
        self.assertEqual(bad.status_code, 400)

    # ---------- inasistencia ----------
    def test_no_show_risk_baseline(self):
        slot = self.publish(48)[0]
        appt = self.book(slot["id"], priority="ALTA").get_json()
        r = self.c.get(f"/appointments/{appt['id']}/no-show-risk", headers=self.staff)
        self.assertEqual(r.status_code, 200)
        data = r.get_json()
        self.assertTrue(0 < data["noShowProbability"] < 1)
        self.assertEqual(data["model"], "rule-based-baseline-v0")
        self.assertEqual(self.c.get(f"/appointments/{appt['id']}/no-show-risk",
                                    headers=self.student).status_code, 403)

    def test_priority_does_not_change_no_show_score(self):
        a, b = self.publish(48, 49)
        normal = self.book(a["id"], priority="NORMAL").get_json()
        alta = self.book(b["id"], priority="ALTA").get_json()
        p1 = self.c.get(f"/appointments/{normal['id']}/no-show-risk", headers=self.staff).get_json()
        p2 = self.c.get(f"/appointments/{alta['id']}/no-show-risk", headers=self.staff).get_json()
        self.assertEqual(p1["noShowProbability"], p2["noShowProbability"])

    def test_no_show_risk_only_for_active_appointments(self):
        slot = self.publish(2)[0]
        appt = self.book(slot["id"]).get_json()
        self.c.patch(f"/appointments/{appt['id']}/cancel", json={}, headers=self.staff)
        r = self.c.get(f"/appointments/{appt['id']}/no-show-risk", headers=self.staff)
        self.assertEqual(r.status_code, 409)

    def _capture_service(self):
        captured = {}

        class Capture(NoShowPredictor):
            MODEL = "capture"

            def predict(self, features):
                captured.update(features)
                return {"probability": 0.1, "factors": [], "model": "capture"}

        clock = lambda: self.now
        return (SlotService(self.slots_repo, clock),
                AppointmentService(self.slots_repo, self.apps_repo, Capture(), clock), captured)

    def test_risk_features_use_calendar_days_in_lima(self):
        # Agendada a las 23:00 (Lima) del 9-nov para las 09:00 del 10-nov = 1 día, no "mismo día".
        self.now = datetime(2026, 11, 10, 4, 0, tzinfo=timezone.utc)
        slots, appts, captured = self._capture_service()
        slot = slots.publish(10, "PERSONAL_UNAYOE",
                             [datetime(2026, 11, 10, 14, 0, tzinfo=timezone.utc)], None)[0]
        appt = appts.request(1, slot.id, None, None)
        appts.no_show_risk(appt.id, 10, "PERSONAL_UNAYOE")
        self.assertEqual(captured["lead_days"], 1)
        self.assertEqual(captured["hour_local"], 9)

    def test_risk_history_counts_only_earlier_appointments(self):
        slots, appts, captured = self._capture_service()
        early = slots.publish(10, "PERSONAL_UNAYOE", [self.now + timedelta(hours=48)], None)[0]
        first = appts.request(1, early.id, None, None)
        self.now += timedelta(hours=60)                       # la 1.ª cita ya ocurrió
        appts.change_status(first.id, 10, "PERSONAL_UNAYOE", "CONFIRMADA")
        appts.change_status(first.id, 10, "PERSONAL_UNAYOE", "NO_ASISTIO")
        late = slots.publish(10, "PERSONAL_UNAYOE", [self.now + timedelta(hours=48)], None)[0]
        second = appts.request(1, late.id, None, None)
        appts.no_show_risk(second.id, 10, "PERSONAL_UNAYOE")
        self.assertEqual(captured["prior_no_shows"], 1)       # solo la anterior, no la actual

    # ---------------- concurrencia (bloqueo optimista) ----------------
    def _lose_race(self, appointment_id):
        """La próxima lectura de la cita devuelve una copia vieja: otra operación ya la canceló."""
        real_get = self.apps_repo.get
        winner = real_get(appointment_id)
        winner.status = AppointmentStatus.CANCELADA
        self.apps_repo.update(winner)
        stale = real_get(appointment_id)
        stale.status = AppointmentStatus.SOLICITADA
        self.apps_repo.get = lambda _id: stale
        self.addCleanup(setattr, self.apps_repo, "get", real_get)

    def test_reschedule_that_loses_a_race_releases_the_new_slot(self):
        a, b = self.publish(48, 72)
        appt = self.book(a["id"]).get_json()
        self._lose_race(appt["id"])
        r = self.c.patch(f"/appointments/{appt['id']}/reschedule", json={"slotId": b["id"]},
                         headers=self.student)
        self.assertEqual(r.status_code, 409)
        free = [s["id"] for s in self.c.get("/slots", headers=self.student).get_json()]
        self.assertIn(b["id"], free, "el horario nuevo no debe quedar reservado")

    def test_cancel_and_status_that_lose_a_race_return_conflict(self):
        slot = self.publish(2)[0]
        appt = self.book(slot["id"]).get_json()
        self._lose_race(appt["id"])
        r = self.c.patch(f"/appointments/{appt['id']}/status", json={"status": "CONFIRMADA"},
                         headers=self.staff)
        self.assertEqual(r.status_code, 409)

    # ---------------- validaciones de entrada ----------------
    def test_staff_user_id_query_is_validated(self):
        for bad in ("abc", "²", "0", "-3", "1.5"):
            r = self.c.get(f"/slots?staffUserId={bad}", headers=self.student)
            self.assertEqual(r.status_code, 400, bad)
        self.assertEqual(self.c.get("/slots?staffUserId=10", headers=self.student).status_code, 200)

    def test_extreme_dates_are_rejected_not_500(self):
        r = self.c.post("/slots", json={"startAts": ["0001-01-01T00:00:00+05:00"]}, headers=self.staff)
        self.assertEqual(r.status_code, 400)
        r = self.c.get("/slots?from=9999-12-31T23:59:59-05:00", headers=self.student)
        self.assertEqual(r.status_code, 400)

    def test_token_without_expiry_is_rejected(self):
        no_exp = jwt.encode({"userId": 1, "role": "ESTUDIANTE"}, SECRET, algorithm="HS256")
        r = self.c.get("/slots", headers={"Authorization": f"Bearer {no_exp}"})
        self.assertEqual(r.status_code, 401)

    def test_publish_conflict_is_all_or_nothing(self):
        self.publish(48)
        dup = self.c.post("/slots", json={"startAts": [iso(self.now + timedelta(hours=47)),
                                                       iso(self.now + timedelta(hours=48))]},
                          headers=self.staff)
        self.assertEqual(dup.status_code, 409)
        self.assertEqual(len(self.c.get("/slots", headers=self.student).get_json()), 1)

    def _post_slots(self, *minutes_ahead, headers=None):
        starts = [iso(self.now + timedelta(minutes=m)) for m in minutes_ahead]
        return self.c.post("/slots", json={"startAts": starts}, headers=headers or self.staff)

    def test_publish_rejects_overlapping_starts_in_same_request(self):
        # 10:00 y 10:15 del mismo personal: cada horario dura 30 min, se solapan.
        base = 48 * 60
        r = self._post_slots(base, base + 15)
        self.assertEqual(r.status_code, 400)
        self.assertIn("solapar", r.get_json()["message"])
        self.assertEqual(self.c.get("/slots", headers=self.student).get_json(), [])

    def test_publish_rejects_overlap_with_already_published_slot(self):
        base = 48 * 60
        self.assertEqual(self._post_slots(base).status_code, 201)
        for offset in (-15, 15, 29):
            r = self._post_slots(base + offset)
            self.assertEqual(r.status_code, 409, offset)
            self.assertIn("se solapa", r.get_json()["message"])
        # Exactamente contiguos no se solapan: se permiten antes y después.
        self.assertEqual(self._post_slots(base - 30, base + 30).status_code, 201)

    def test_publish_overlap_is_checked_per_staff(self):
        base = 48 * 60
        self.assertEqual(self._post_slots(base).status_code, 201)
        otro = auth(11, "PERSONAL_UNAYOE")
        self.assertEqual(self._post_slots(base + 15, headers=otro).status_code, 201)

    # ---------------- recordatorios dentro de la app ----------------
    def _reminders_client(self, probability=0.1, fail=False):
        """Cliente cuyo predictor devuelve siempre [probability] (o falla), con umbral 0.30."""
        class Fixed(NoShowPredictor):
            MODEL = "fijo"

            def predict(self, features):
                if fail:
                    raise RuntimeError("modelo caído")
                return {"probability": probability, "factors": ["x"], "model": "fijo"}

        clock = lambda: self.now
        app = create_http_app(
            SlotService(self.slots_repo, clock),
            AppointmentService(self.slots_repo, self.apps_repo, Fixed(), clock),
            JwtTokenService(SECRET), lambda: True)
        return app.test_client()

    def _reminders(self, client=None, headers=None):
        r = (client or self.c).get("/appointments/me/reminders", headers=headers or self.student)
        self.assertEqual(r.status_code, 200, r.get_json())
        return r.get_json()

    def test_reminders_require_student_role(self):
        self.assertEqual(self.c.get("/appointments/me/reminders").status_code, 401)
        r = self.c.get("/appointments/me/reminders", headers=self.staff)
        self.assertEqual(r.status_code, 403)

    def test_reminders_empty_without_appointments(self):
        self.assertEqual(self._reminders(), [])

    def test_standard_reminder_appears_24_hours_before(self):
        low = self._reminders_client(probability=0.05)
        a = self.book(self.publish(30)[0]["id"]).get_json()      # en 30 h: aún no toca
        b = self.book(self.publish(20)[0]["id"]).get_json()      # en 20 h: ya toca
        items = {i["appointmentId"]: i for i in self._reminders(low)}
        self.assertFalse(items[a["id"]]["dueNow"])
        self.assertTrue(items[b["id"]]["dueNow"])
        self.assertEqual(items[b["id"]]["hoursUntil"], 20)

    def test_reinforced_reminder_appears_48_hours_before(self):
        appt = self.book(self.publish(30)[0]["id"]).get_json()
        high = self._reminders_client(probability=0.5)
        self.assertTrue(self._reminders(high)[0]["dueNow"])
        low = self._reminders_client(probability=0.1)
        self.assertFalse(self._reminders(low)[0]["dueNow"])
        self.assertEqual(self._reminders(high)[0]["appointmentId"], appt["id"])

    def test_reinforced_reminder_does_not_apply_beyond_48_hours(self):
        self.book(self.publish(60)[0]["id"])
        self.assertFalse(self._reminders(self._reminders_client(probability=0.9))[0]["dueNow"])

    def test_reminder_threshold_is_inclusive(self):
        self.book(self.publish(30)[0]["id"])
        self.assertTrue(self._reminders(self._reminders_client(probability=0.30))[0]["dueNow"])
        self.assertFalse(self._reminders(self._reminders_client(probability=0.29))[0]["dueNow"])

    def test_reminders_survive_a_predictor_failure(self):
        self.book(self.publish(30)[0]["id"])
        items = self._reminders(self._reminders_client(fail=True))
        self.assertEqual(len(items), 1)
        self.assertFalse(items[0]["dueNow"])      # sin estimación no hay refuerzo
        # Y una cita a menos de 24 h sigue avisando sin consultar el modelo.
        self.book(self.publish(10)[0]["id"])
        self.assertTrue(all(i["dueNow"] for i in self._reminders(self._reminders_client(fail=True))
                            if i["hoursUntil"] <= 24))

    def test_reminders_only_list_upcoming_active_appointments_in_order(self):
        far = self.book(self.publish(40)[0]["id"]).get_json()
        soon = self.book(self.publish(5)[0]["id"]).get_json()
        items = self._reminders()
        self.assertEqual([i["appointmentId"] for i in items], [soon["id"], far["id"]])
        self.c.patch(f"/appointments/{soon['id']}/cancel", json={}, headers=self.staff)
        self.assertEqual([i["appointmentId"] for i in self._reminders()], [far["id"]])
        self.now += timedelta(hours=41)     # la cita restante ya pasó sin marcarse
        self.assertEqual(self._reminders(), [])

    def test_reminders_are_private_to_each_student(self):
        self.book(self.publish(10)[0]["id"])
        other = auth(2, "ESTUDIANTE")
        self.assertEqual(self._reminders(headers=other), [])
        self.assertEqual(len(self._reminders()), 1)

    def test_reminders_report_when_the_appointment_can_still_change(self):
        self.book(self.publish(20)[0]["id"])
        item = self._reminders()[0]
        self.assertTrue(item["canChange"])
        self.assertEqual(item["canChangeUntil"], iso(self.now + timedelta(hours=8)))
        self.now += timedelta(hours=9)      # faltan 11 h: ya no se puede cambiar desde la app
        item = self._reminders()[0]
        self.assertFalse(item["canChange"])
        self.assertTrue(item["dueNow"])

    def test_reminders_do_not_expose_the_risk_estimate(self):
        self.book(self.publish(30)[0]["id"])
        item = self._reminders(self._reminders_client(probability=0.9))[0]
        self.assertEqual(set(item), {"appointmentId", "staffUserId", "startAt", "endAt", "status",
                                     "hoursUntil", "dueNow", "canChange", "canChangeUntil"})

    def test_malformed_json(self):
        r = self.c.post("/appointments", data="no es json", content_type="application/json",
                        headers=self.student)
        self.assertEqual(r.status_code, 400)


if __name__ == "__main__":
    unittest.main()

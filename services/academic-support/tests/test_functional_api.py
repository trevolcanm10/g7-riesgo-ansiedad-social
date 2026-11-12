from __future__ import annotations

import unittest
from datetime import datetime, timedelta, timezone
from typing import Any
from zoneinfo import ZoneInfo

import jwt

from src.application.academic_support_service import AcademicSupportService
from src.config import Settings
from src.domain.entities import Resource
from src.domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from src.domain.recommender import HybridRecommendationEngine
from src.presentation.http import create_http_app


JWT_SECRET = "functional-test-secret-with-sufficient-length"


class FakeAcademicSupportRepository:
    """In-memory port adapter for HTTP and application functional tests."""

    def __init__(self) -> None:
        self.resources: dict[int, dict[str, Any]] = {}
        self.preferences: dict[int, dict[str, Any]] = {}
        self.enrollments: dict[tuple[int, int], dict[str, Any]] = {}
        self.interactions: list[dict[str, Any]] = []
        self.db_available = True
        self.fail_listing = False
        self._next_resource_id = 1
        self._next_enrollment_id = 1
        self._next_event_id = 1

    def ping(self) -> bool:
        if not self.db_available:
            raise RuntimeError("simulated database outage")
        return True

    @staticmethod
    def _now_utc() -> datetime:
        return datetime.now(timezone.utc).replace(tzinfo=None)

    def add_resource(
        self,
        resource_type: str,
        title: str,
        *,
        tags: list[str] | None = None,
        course_codes: list[str] | None = None,
        modality: str | None = None,
        location: str | None = None,
        start_at: datetime | None = None,
        end_at: datetime | None = None,
        capacity: int | None = None,
        url: str | None = None,
        creator_user_id: int = 900,
        status: str = "PUBLISHED",
        is_synthetic: bool = False,
    ) -> dict[str, Any]:
        resource_id = self._next_resource_id
        self._next_resource_id += 1
        now = self._now_utc()
        record = {
            "id": resource_id,
            "resource_type": resource_type,
            "title": title,
            "description": f"Descripción de {title}",
            "tags": list(tags or []),
            "course_codes": list(course_codes or []),
            "modality": modality,
            "location": location,
            "start_at": start_at,
            "end_at": end_at,
            "capacity": capacity,
            "url": url,
            "creator_user_id": creator_user_id,
            "status": status,
            "is_synthetic": is_synthetic,
            "created_at": now,
            "updated_at": now,
        }
        self.resources[resource_id] = record
        return self._with_capacity(record)

    def _active_count(self, resource_id: int) -> int:
        return sum(
            1
            for (user_id, enrolled_resource_id), enrollment in self.enrollments.items()
            if enrolled_resource_id == resource_id and enrollment["status"] == "ACTIVE"
        )

    def _with_capacity(self, record: dict[str, Any]) -> dict[str, Any]:
        result = dict(record)
        capacity = record.get("capacity")
        result["available_seats"] = (
            None if capacity is None else max(0, capacity - self._active_count(record["id"]))
        )
        result["tags"] = list(record["tags"])
        result["course_codes"] = list(record["course_codes"])
        return result

    def get_preferences(self, user_id: int) -> dict[str, Any]:
        return dict(
            self.preferences.get(
                user_id,
                {
                    "user_id": user_id,
                    "interests": [],
                    "course_codes": [],
                    "available_slots": [],
                    "preferred_modalities": [],
                    "time_zone": "America/Lima",
                    "updated_at": None,
                },
            )
        )

    def save_preferences(self, user_id: int, preferences: dict[str, Any]) -> dict[str, Any]:
        saved = {
            "user_id": user_id,
            **preferences,
            "updated_at": self._now_utc(),
        }
        self.preferences[user_id] = saved
        return dict(saved)

    def list_resources(
        self,
        resource_type: str | None = None,
        course_code: str | None = None,
        tag: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[dict[str, Any]], int]:
        if self.fail_listing:
            raise RuntimeError("simulated storage failure")
        now = self._now_utc()
        records = [
            item
            for item in self.resources.values()
            if item["status"] == "PUBLISHED"
            and (item["end_at"] is None or item["end_at"] > now)
            and (resource_type is None or item["resource_type"] == resource_type)
            and (course_code is None or course_code in item["course_codes"])
            and (tag is None or tag in item["tags"])
        ]
        records.sort(
            key=lambda item: (
                item["start_at"] is None,
                item["start_at"] or datetime.max,
                item["id"],
            )
        )
        total = len(records)
        page = records[offset : offset + limit]
        return [self._with_capacity(item) for item in page], total

    def get_published_resource(self, resource_id: int) -> dict[str, Any] | None:
        record = self.resources.get(resource_id)
        if record is None or record["status"] != "PUBLISHED":
            return None
        return self._with_capacity(record)

    def get_resource_record(self, resource_id: int) -> dict[str, Any] | None:
        record = self.resources.get(resource_id)
        return self._with_capacity(record) if record else None

    def create_resource(
        self, data: dict[str, Any], creator_user_id: int, creator_role: str
    ) -> dict[str, Any]:
        if (
            creator_role == "ESTUDIANTE"
            and data["resource_type"] == "TUTORING"
            and any(
                item["creator_user_id"] == creator_user_id
                and item["resource_type"] == "TUTORING"
                and item["status"] == "PUBLISHED"
                for item in self.resources.values()
            )
        ):
            raise ConflictError(
                "Ya tienes una tutoría publicada; cancélala antes de crear otra"
            )
        record = self.add_resource(
            data["resource_type"],
            data["title"],
            tags=data["tags"],
            course_codes=data["course_codes"],
            modality=data["modality"],
            location=data["location"],
            start_at=data["start_at"],
            end_at=data["end_at"],
            capacity=data["capacity"],
            url=data["url"],
            creator_user_id=creator_user_id,
        )
        return record

    def update_resource(
        self,
        resource_id: int,
        data: dict[str, Any],
        actor_user_id: int,
        actor_role: str,
    ) -> dict[str, Any]:
        record = self.resources.get(resource_id)
        if record is None:
            raise NotFoundError()
        is_staff = actor_role in {"PERSONAL_UNAYOE", "ADMINISTRADOR"}
        is_owner_tutor = (
            record["resource_type"] == "TUTORING"
            and record["creator_user_id"] == actor_user_id
        )
        if not (is_staff or is_owner_tutor):
            raise ForbiddenError()
        new_capacity = data.get("capacity")
        if new_capacity is not None and new_capacity < self._active_count(resource_id):
            raise ConflictError(
                "La capacidad no puede ser menor que las inscripciones activas"
            )
        record.update(data)
        record["updated_at"] = self._now_utc()
        return self._with_capacity(record)

    def cancel_resource(
        self, resource_id: int, actor_user_id: int, actor_role: str
    ) -> None:
        record = self.resources.get(resource_id)
        if record is None:
            raise NotFoundError()
        is_staff = actor_role in {"PERSONAL_UNAYOE", "ADMINISTRADOR"}
        is_owner_tutor = (
            record["resource_type"] == "TUTORING"
            and record["creator_user_id"] == actor_user_id
        )
        if not (is_staff or is_owner_tutor):
            raise ForbiddenError()
        record["status"] = "CANCELLED"
        for (user_id, enrolled_resource_id), enrollment in self.enrollments.items():
            if enrolled_resource_id == resource_id and enrollment["status"] == "ACTIVE":
                enrollment["status"] = "CANCELLED"

    def get_recommendation_inputs(
        self, user_id: int
    ) -> tuple[list[dict[str, Any]], dict[str, Any], list[dict[str, Any]], set[int]]:
        now = self._now_utc()
        enrolled_ids = {
            resource_id
            for (enrolled_user_id, resource_id), enrollment in self.enrollments.items()
            if enrolled_user_id == user_id and enrollment["status"] == "ACTIVE"
        }
        resources = [
            self._with_capacity(item)
            for item in self.resources.values()
            if item["status"] == "PUBLISHED"
            and (item["end_at"] is None or item["end_at"] > now)
            and (
                item["capacity"] is None
                or item["capacity"] > self._active_count(item["id"])
            )
            and item["id"] not in enrolled_ids
        ]
        interactions = sorted(
            self.interactions,
            key=lambda event: (event["created_at"], event["id"]),
            reverse=True,
        )
        return resources, self.get_preferences(user_id), interactions, enrolled_ids

    def _record_event(self, user_id: int, resource_id: int, event_type: str) -> None:
        event_id = self._next_event_id
        self._next_event_id += 1
        self.interactions.append(
            {
                "id": event_id,
                "user_id": user_id,
                "resource_id": resource_id,
                "event_type": event_type,
                "created_at": self._now_utc() + timedelta(microseconds=event_id),
            }
        )

    def record_interaction(self, user_id: int, resource_id: int, event_type: str) -> None:
        record = self.resources.get(resource_id)
        if record is None:
            raise NotFoundError("No se encontró el recurso")
        if record["status"] != "PUBLISHED":
            raise ConflictError("El recurso ya no está disponible")
        self._record_event(user_id, resource_id, event_type)

    def enroll_in_workshop(self, user_id: int, resource_id: int) -> dict[str, Any]:
        record = self.resources.get(resource_id)
        if record is None:
            raise NotFoundError("No se encontró el taller")
        if record["resource_type"] != "WORKSHOP":
            raise ValidationError("El recurso indicado no es un taller")
        if record["status"] != "PUBLISHED":
            raise ConflictError("El taller ya no está disponible")
        if record["end_at"] and record["end_at"] <= self._now_utc():
            raise ConflictError("El taller ya finalizó")
        key = (user_id, resource_id)
        existing = self.enrollments.get(key)
        if existing and existing["status"] == "ACTIVE":
            raise ConflictError("Ya tienes una inscripción activa en este taller")
        capacity = record["capacity"]
        if capacity is not None and self._active_count(resource_id) >= capacity:
            raise ConflictError("El taller ya no tiene cupos disponibles")
        now = self._now_utc()
        if existing:
            existing["status"] = "ACTIVE"
            existing["enrolled_at"] = now
            enrollment = existing
        else:
            enrollment = {
                "id": self._next_enrollment_id,
                "resource_id": resource_id,
                "user_id": user_id,
                "status": "ACTIVE",
                "enrolled_at": now,
            }
            self._next_enrollment_id += 1
            self.enrollments[key] = enrollment
        self._record_event(user_id, resource_id, "ENROLL")
        return {
            "id": enrollment["id"],
            "resourceId": resource_id,
            "userId": user_id,
            "status": "ACTIVE",
            "enrolledAt": enrollment["enrolled_at"].replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
        }

    def cancel_workshop_enrollment(self, user_id: int, resource_id: int) -> None:
        enrollment = self.enrollments.get((user_id, resource_id))
        if enrollment is None or enrollment["status"] != "ACTIVE":
            raise NotFoundError("No tienes una inscripción activa en este taller")
        enrollment["status"] = "CANCELLED"
        self._record_event(user_id, resource_id, "WITHDRAW")

    def list_user_enrollments(self, user_id: int) -> list[dict[str, Any]]:
        result = []
        for (enrolled_user_id, resource_id), enrollment in self.enrollments.items():
            if enrolled_user_id != user_id or enrollment["status"] != "ACTIVE":
                continue
            resource = self._with_capacity(self.resources[resource_id])
            result.append(
                {
                    "id": enrollment["id"],
                    "resourceId": resource_id,
                    "status": "ACTIVE",
                    "enrolledAt": enrollment["enrolled_at"].replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
                    "workshop": {
                        "id": resource_id,
                        "title": resource["title"],
                        "description": resource["description"],
                        "startAt": resource["start_at"].replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
                        "endAt": resource["end_at"].replace(tzinfo=timezone.utc).isoformat().replace("+00:00", "Z"),
                        "location": resource["location"],
                        "modality": resource["modality"],
                        "capacity": resource["capacity"],
                        "availableSeats": resource["available_seats"],
                    },
                }
            )
        return result


class AcademicSupportFunctionalApiTests(unittest.TestCase):
    def setUp(self) -> None:
        self.repository = FakeAcademicSupportRepository()
        lima = ZoneInfo("America/Lima")
        local_start = (datetime.now(lima) + timedelta(days=7)).replace(
            hour=15, minute=0, second=0, microsecond=0
        )
        start_at = local_start.astimezone(timezone.utc).replace(tzinfo=None)
        end_at = start_at + timedelta(hours=1)
        self.workshop_id = self.repository.add_resource(
            "WORKSHOP",
            "Organización del tiempo",
            tags=["organización del tiempo", "técnicas de estudio"],
            course_codes=["MAT101"],
            modality="REMOTO",
            start_at=start_at,
            end_at=end_at,
            capacity=3,
        )["id"]
        self.material_id = self.repository.add_resource(
            "MATERIAL",
            "Guía de programación",
            tags=["programación", "python"],
            course_codes=["INF101"],
            url="https://example.org/python",
        )["id"]
        settings = Settings(
            port=5003,
            db_host="unused",
            db_port=3306,
            db_name="unused",
            db_user="unused",
            db_password="",
            jwt_secret=JWT_SECRET,
        )
        service = AcademicSupportService(
            self.repository,
            HybridRecommendationEngine(),
        )
        self.app = create_http_app(settings, service, self.repository)
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()

    @staticmethod
    def token(
        user_id: int = 101,
        role: str = "ESTUDIANTE",
        *,
        expires_in: int = 3600,
    ) -> str:
        now = datetime.now(timezone.utc)
        return jwt.encode(
            {
                "userId": user_id,
                "role": role,
                "iat": now,
                "exp": now + timedelta(seconds=expires_in),
            },
            JWT_SECRET,
            algorithm="HS256",
        )

    def headers(self, user_id: int = 101, role: str = "ESTUDIANTE") -> dict[str, str]:
        return {"Authorization": f"Bearer {self.token(user_id, role)}"}

    def workshop_payload(self, **overrides: Any) -> dict[str, Any]:
        start = datetime.now(timezone.utc) + timedelta(days=4)
        payload = {
            "type": "WORKSHOP",
            "title": "Taller de muestra",
            "description": "Descripción breve",
            "tags": ["planificación"],
            "courseCodes": ["MAT101"],
            "modality": "PRESENCIAL",
            "location": "Aula 2",
            "startAt": start.isoformat().replace("+00:00", "Z"),
            "endAt": (start + timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
            "capacity": 2,
        }
        payload.update(overrides)
        return payload

    def test_01_health_returns_200_when_database_is_available(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["database"], "OK")

    def test_02_health_returns_503_when_database_is_unavailable(self) -> None:
        self.repository.db_available = False
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.json["database"], "UNAVAILABLE")

    def test_03_catalog_requires_authentication(self) -> None:
        response = self.client.get("/resources")
        self.assertEqual(response.status_code, 401)
        self.assertIn("message", response.json)

    def test_04_malformed_and_expired_tokens_are_rejected(self) -> None:
        malformed = self.client.get(
            "/resources", headers={"Authorization": "Basic broken"}
        )
        expired = self.client.get(
            "/resources",
            headers={"Authorization": f"Bearer {self.token(expires_in=-60)}"},
        )
        self.assertEqual(malformed.status_code, 401)
        self.assertEqual(expired.status_code, 401)

    def test_05_catalog_lists_filters_and_paginates(self) -> None:
        response = self.client.get("/resources?type=MATERIAL", headers=self.headers())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["pagination"]["total"], 1)
        self.assertEqual(response.json["items"][0]["type"], "MATERIAL")

        page = self.client.get("/resources?limit=1&offset=0", headers=self.headers())
        self.assertEqual(page.status_code, 200)
        self.assertEqual(len(page.json["items"]), 1)
        self.assertEqual(page.json["pagination"]["total"], 2)

    def test_06_catalog_rejects_invalid_filters_and_pagination(self) -> None:
        invalid_type = self.client.get("/resources?type=UNKNOWN", headers=self.headers())
        invalid_limit = self.client.get("/resources?limit=101", headers=self.headers())
        self.assertEqual(invalid_type.status_code, 400)
        self.assertEqual(invalid_limit.status_code, 400)

    def test_07_catalog_omits_expired_and_cancelled_resources(self) -> None:
        past = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=2)
        self.repository.add_resource(
            "WORKSHOP",
            "Taller vencido",
            tags=["planificación"],
            modality="REMOTO",
            start_at=past - timedelta(hours=1),
            end_at=past,
            capacity=10,
        )
        cancelled = self.repository.add_resource(
            "MATERIAL",
            "Material cancelado",
            tags=["lectura"],
            url="https://example.org/cancelado",
            status="CANCELLED",
        )
        response = self.client.get("/resources", headers=self.headers())
        titles = {item["title"] for item in response.json["items"]}
        self.assertEqual(response.status_code, 200)
        self.assertNotIn("Taller vencido", titles)
        self.assertNotIn("Material cancelado", titles)

    def test_08_preferences_are_private_and_round_trip(self) -> None:
        forbidden = self.client.get(
            "/students/me/preferences",
            headers=self.headers(user_id=900, role="PERSONAL_UNAYOE"),
        )
        self.assertEqual(forbidden.status_code, 403)

        saved = self.client.put(
            "/students/me/preferences",
            headers=self.headers(user_id=101),
            json={
                "interests": ["programación"],
                "courseCodes": ["INF101"],
                "availableSlots": [
                    {"weekday": 2, "startTime": "14:00", "endTime": "18:00"}
                ],
                "preferredModalities": ["REMOTO"],
                "timeZone": "America/Lima",
            },
        )
        loaded = self.client.get(
            "/students/me/preferences", headers=self.headers(user_id=101)
        )
        self.assertEqual(saved.status_code, 200)
        self.assertEqual(loaded.status_code, 200)
        self.assertEqual(loaded.json["interests"], ["programación"])
        self.assertEqual(loaded.json["courseCodes"], ["INF101"])
        self.assertEqual(loaded.json["timeZone"], "America/Lima")
        self.assertIsNotNone(loaded.json["updatedAt"])

    def test_09_preferences_validate_slots_and_time_zone(self) -> None:
        bad_slot = self.client.put(
            "/students/me/preferences",
            headers=self.headers(),
            json={
                "availableSlots": [
                    {"weekday": 7, "startTime": "15:00", "endTime": "14:00"}
                ]
            },
        )
        bad_zone = self.client.put(
            "/students/me/preferences",
            headers=self.headers(),
            json={"timeZone": "Mars/Olympus"},
        )
        self.assertEqual(bad_slot.status_code, 400)
        self.assertEqual(bad_zone.status_code, 400)

    def test_10_preference_update_rejects_unknown_fields(self) -> None:
        response = self.client.put(
            "/students/me/preferences",
            headers=self.headers(),
            json={"userId": 999, "interests": ["python"]},
        )
        self.assertEqual(response.status_code, 400)

    def test_11_content_recommender_matches_interests_courses_and_schedule(self) -> None:
        local_start = self.repository.resources[self.workshop_id]["start_at"].replace(
            tzinfo=timezone.utc
        ).astimezone(ZoneInfo("America/Lima"))
        self.client.put(
            "/students/me/preferences",
            headers=self.headers(),
            json={
                "interests": ["tecnicas de estudio"],
                "courseCodes": ["MAT101"],
                "availableSlots": [
                    {
                        "weekday": local_start.weekday(),
                        "startTime": "14:00",
                        "endTime": "16:00",
                    }
                ],
                "preferredModalities": ["REMOTO"],
                "timeZone": "America/Lima",
            },
        )
        response = self.client.get("/recommendations", headers=self.headers())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["recommendationMode"], "CONTENT_BASED")
        best = response.json["items"][0]
        self.assertEqual(best["resource"]["id"], self.workshop_id)
        self.assertTrue(any("intereses" in reason for reason in best["reasons"]))
        self.assertTrue(any("cursos" in reason for reason in best["reasons"]))
        self.assertTrue(any("horario" in reason for reason in best["reasons"]))

    def test_12_empty_profile_uses_popularity_fallback(self) -> None:
        response = self.client.get("/recommendations", headers=self.headers())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["recommendationMode"], "POPULARITY_FALLBACK")
        self.assertTrue(response.json["items"])
        self.assertEqual(
            response.json["items"][0]["recommendationMode"],
            "POPULARITY_FALLBACK",
        )

    def test_13_item_collaborative_signal_switches_to_hybrid(self) -> None:
        self.repository._record_event(101, self.workshop_id, "CLICK")
        self.repository._record_event(202, self.workshop_id, "CLICK")
        self.repository._record_event(202, self.material_id, "CLICK")
        response = self.client.get("/recommendations", headers=self.headers())
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json["recommendationMode"], "HYBRID")
        material = next(
            item for item in response.json["items"]
            if item["resource"]["id"] == self.material_id
        )
        self.assertTrue(
            any("interacciones similares" in reason for reason in material["reasons"])
        )

    def test_13a_repeated_interactions_do_not_inflate_recommendation_scores(self) -> None:
        self.repository._record_event(101, self.workshop_id, "CLICK")
        self.repository._record_event(202, self.workshop_id, "CLICK")
        self.repository._record_event(202, self.material_id, "CLICK")
        baseline = self.client.get("/recommendations", headers=self.headers())
        baseline_scores = {
            item["resource"]["id"]: item["score"] for item in baseline.json["items"]
        }

        for _ in range(100):
            self.repository._record_event(202, self.workshop_id, "CLICK")
        repeated = self.client.get("/recommendations", headers=self.headers())
        repeated_scores = {
            item["resource"]["id"]: item["score"] for item in repeated.json["items"]
        }

        self.assertEqual(baseline.status_code, 200)
        self.assertEqual(repeated.status_code, 200)
        self.assertEqual(baseline_scores, repeated_scores)

    def test_14_latest_dismissal_suppresses_resource_recommendation(self) -> None:
        self.repository._record_event(101, self.workshop_id, "CLICK")
        self.repository._record_event(101, self.workshop_id, "DISMISS")
        response = self.client.get("/recommendations", headers=self.headers())
        ids = {item["resource"]["id"] for item in response.json["items"]}
        self.assertNotIn(self.workshop_id, ids)

    def test_15_recommendations_exclude_full_and_active_enrollments(self) -> None:
        full_id = self.repository.add_resource(
            "WORKSHOP",
            "Taller lleno",
            tags=["estudio"],
            modality="REMOTO",
            start_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=3),
            end_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=3, hours=1),
            capacity=1,
        )["id"]
        self.repository.enroll_in_workshop(202, full_id)
        self.repository.enroll_in_workshop(101, self.workshop_id)
        response = self.client.get("/recommendations", headers=self.headers())
        ids = {item["resource"]["id"] for item in response.json["items"]}
        self.assertNotIn(full_id, ids)
        self.assertNotIn(self.workshop_id, ids)

    def test_16_student_can_publish_only_one_active_tutoring_offer(self) -> None:
        start = datetime.now(timezone.utc) + timedelta(days=5)
        tutoring = {
            "type": "TUTORING",
            "title": "Tutoría de prueba",
            "description": "Apoyo entre pares",
            "tags": ["programación"],
            "courseCodes": ["INF101"],
            "modality": "REMOTO",
            "startAt": start.isoformat().replace("+00:00", "Z"),
            "endAt": (start + timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
        }
        created = self.client.post(
            "/resources", headers=self.headers(user_id=301), json=tutoring
        )
        denied = self.client.post(
            "/resources",
            headers=self.headers(user_id=301),
            json=self.workshop_payload(),
        )
        duplicate = self.client.post(
            "/resources", headers=self.headers(user_id=301), json=tutoring
        )
        another_student = self.client.post(
            "/resources", headers=self.headers(user_id=302), json=tutoring
        )
        cancelled = self.client.delete(
            f"/resources/{created.json['id']}", headers=self.headers(user_id=301)
        )
        replacement = self.client.post(
            "/resources", headers=self.headers(user_id=301), json=tutoring
        )
        self.assertEqual(created.status_code, 201)
        self.assertEqual(created.json["providerUserId"], 301)
        self.assertEqual(denied.status_code, 403)
        self.assertEqual(duplicate.status_code, 409)
        self.assertEqual(another_student.status_code, 201)
        self.assertEqual(cancelled.status_code, 204)
        self.assertEqual(replacement.status_code, 201)

    def test_17_staff_can_publish_workshop_and_material(self) -> None:
        workshop = self.client.post(
            "/resources",
            headers=self.headers(user_id=900, role="PERSONAL_UNAYOE"),
            json=self.workshop_payload(),
        )
        material = self.client.post(
            "/resources",
            headers=self.headers(user_id=900, role="ADMINISTRADOR"),
            json={
                "type": "MATERIAL",
                "title": "Lectura de muestra",
                "description": "Material revisado",
                "tags": ["lectura"],
                "courseCodes": [],
                "url": "https://example.org/lectura",
            },
        )
        self.assertEqual(workshop.status_code, 201)
        self.assertEqual(material.status_code, 201)
        self.assertFalse(material.json["isSynthetic"])

    def test_18_resource_validation_rejects_missing_capacity_and_unsafe_url(self) -> None:
        missing_capacity = self.client.post(
            "/resources",
            headers=self.headers(role="PERSONAL_UNAYOE"),
            json=self.workshop_payload(capacity=None),
        )
        unsafe_url = self.client.post(
            "/resources",
            headers=self.headers(role="PERSONAL_UNAYOE"),
            json={
                "type": "MATERIAL",
                "title": "Enlace inválido",
                "description": "Debe rechazarse",
                "tags": ["lectura"],
                "url": "javascript:alert(1)",
            },
        )
        self.assertEqual(missing_capacity.status_code, 400)
        self.assertEqual(unsafe_url.status_code, 400)

    def test_19_only_owner_or_staff_can_update_and_cancel(self) -> None:
        start = datetime.now(timezone.utc) + timedelta(days=5)
        tutoring = self.client.post(
            "/resources",
            headers=self.headers(user_id=301),
            json={
                "type": "TUTORING",
                "title": "Tutoría propia",
                "description": "Apoyo entre pares",
                "tags": ["programación"],
                "courseCodes": [],
                "modality": "REMOTO",
                "startAt": start.isoformat().replace("+00:00", "Z"),
                "endAt": (start + timedelta(hours=1)).isoformat().replace("+00:00", "Z"),
            },
        )
        resource_id = tutoring.json["id"]
        denied = self.client.patch(
            f"/resources/{resource_id}",
            headers=self.headers(user_id=302),
            json={"title": "Título ajeno"},
        )
        updated = self.client.patch(
            f"/resources/{resource_id}",
            headers=self.headers(user_id=301),
            json={"title": "Título actualizado"},
        )
        cancelled = self.client.delete(
            f"/resources/{resource_id}", headers=self.headers(user_id=301)
        )
        missing = self.client.get(
            f"/resources/{resource_id}", headers=self.headers(user_id=301)
        )
        self.assertEqual(denied.status_code, 403)
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.json["title"], "Título actualizado")
        self.assertEqual(cancelled.status_code, 204)
        self.assertEqual(missing.status_code, 404)

    def test_20_capacity_cannot_be_reduced_below_active_enrollments(self) -> None:
        resource_id = self.repository.add_resource(
            "WORKSHOP",
            "Cupo administrado",
            tags=["estudio"],
            modality="REMOTO",
            start_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=5),
            end_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=5, hours=1),
            capacity=3,
        )["id"]
        self.repository.enroll_in_workshop(101, resource_id)
        self.repository.enroll_in_workshop(102, resource_id)
        response = self.client.patch(
            f"/resources/{resource_id}",
            headers=self.headers(user_id=900, role="PERSONAL_UNAYOE"),
            json={"capacity": 1},
        )
        self.assertEqual(response.status_code, 409)

    def test_21_interactions_are_owned_by_jwt_and_validate_event_type(self) -> None:
        created = self.client.post(
            "/interactions",
            headers=self.headers(user_id=101),
            json={"resourceId": self.material_id, "eventType": "VIEW"},
        )
        spoofed = self.client.post(
            "/interactions",
            headers=self.headers(user_id=101),
            json={
                "resourceId": self.material_id,
                "eventType": "CLICK",
                "userId": 202,
            },
        )
        invalid = self.client.post(
            "/interactions",
            headers=self.headers(),
            json={"resourceId": self.material_id, "eventType": "ENROLL"},
        )
        self.assertEqual(created.status_code, 201)
        self.assertEqual(self.repository.interactions[-1]["user_id"], 101)
        self.assertEqual(spoofed.status_code, 400)
        self.assertEqual(invalid.status_code, 400)

    def test_22_student_can_enroll_and_list_active_workshop(self) -> None:
        response = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        listing = self.client.get(
            "/students/me/enrollments", headers=self.headers(user_id=101)
        )
        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json["status"], "ACTIVE")
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(len(listing.json["items"]), 1)
        self.assertEqual(
            listing.json["items"][0]["workshop"]["availableSeats"], 2
        )

    def test_23_duplicate_enrollment_is_rejected(self) -> None:
        first = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        second = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 409)

    def test_24_capacity_limit_is_enforced(self) -> None:
        one_seat_id = self.repository.add_resource(
            "WORKSHOP",
            "Último cupo",
            tags=["estudio"],
            modality="REMOTO",
            start_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=4),
            end_at=datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=4, hours=1),
            capacity=1,
        )["id"]
        first = self.client.post(
            f"/workshops/{one_seat_id}/enroll",
            headers=self.headers(user_id=101),
        )
        second = self.client.post(
            f"/workshops/{one_seat_id}/enroll",
            headers=self.headers(user_id=102),
        )
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 409)
        self.assertIn("cupos", second.json["message"])

    def test_25_non_workshop_and_expired_workshop_cannot_be_enrolled(self) -> None:
        wrong_type = self.client.post(
            f"/workshops/{self.material_id}/enroll",
            headers=self.headers(),
        )
        past = datetime.now(timezone.utc).replace(tzinfo=None) - timedelta(days=3)
        expired_id = self.repository.add_resource(
            "WORKSHOP",
            "Taller finalizado",
            tags=["estudio"],
            modality="REMOTO",
            start_at=past - timedelta(hours=1),
            end_at=past,
            capacity=10,
        )["id"]
        expired = self.client.post(
            f"/workshops/{expired_id}/enroll",
            headers=self.headers(),
        )
        self.assertEqual(wrong_type.status_code, 400)
        self.assertEqual(expired.status_code, 409)

    def test_26_cancellation_releases_seat_and_can_be_rebooked(self) -> None:
        first = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        cancelled = self.client.delete(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        second = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(user_id=101),
        )
        self.assertEqual(first.status_code, 201)
        self.assertEqual(cancelled.status_code, 204)
        self.assertEqual(second.status_code, 201)

    def test_27_staff_cannot_use_student_preferences_or_enroll(self) -> None:
        preferences = self.client.get(
            "/students/me/preferences",
            headers=self.headers(role="ADMINISTRADOR"),
        )
        enrollment = self.client.post(
            f"/workshops/{self.workshop_id}/enroll",
            headers=self.headers(role="PERSONAL_UNAYOE"),
        )
        self.assertEqual(preferences.status_code, 403)
        self.assertEqual(enrollment.status_code, 403)

    def test_28_unknown_route_returns_json_error(self) -> None:
        response = self.client.get("/not-a-route")
        self.assertEqual(response.status_code, 404)
        self.assertIn("message", response.json)

    def test_29_storage_failure_returns_generic_500(self) -> None:
        self.repository.fail_listing = True
        response = self.client.get("/resources", headers=self.headers())
        self.assertEqual(response.status_code, 500)
        self.assertEqual(response.json, {"message": "Error interno del servicio"})


if __name__ == "__main__":
    unittest.main()

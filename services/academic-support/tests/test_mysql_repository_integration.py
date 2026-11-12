from __future__ import annotations

import os
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from src.config import Settings
from src.domain.errors import ConflictError
from src.infrastructure.mysql_repository import MySqlAcademicSupportRepository


SERVICE_DIR = Path(__file__).resolve().parents[1]
load_dotenv(SERVICE_DIR / ".env", override=False)
MYSQL_INTEGRATION_ENABLED = (
    os.getenv("ACADEMIC_SUPPORT_MYSQL_INTEGRATION", "").strip() == "1"
)


@unittest.skipUnless(
    MYSQL_INTEGRATION_ENABLED,
    "Activa ACADEMIC_SUPPORT_MYSQL_INTEGRATION=1 para probar MySQL real",
)
class MySqlRepositoryIntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.settings = Settings.from_environment()
        if not cls.settings.db_name.lower().endswith("_test"):
            raise RuntimeError(
                "Las pruebas de integración modifican datos: DB_NAME debe terminar en _test"
            )
        cls.repository = MySqlAcademicSupportRepository(cls.settings)

    def setUp(self) -> None:
        self.suffix = uuid.uuid4().hex[:12]
        self.user_id = 1_000_000_000 + (uuid.uuid4().int % 1_000_000_000)
        self.user_ids = {self.user_id}
        self.resource_ids: set[int] = set()
        self.tag = f"it-{self.suffix}"
        self.course_code = f"IT{self.suffix[:8].upper()}"

    def tearDown(self) -> None:
        if not self.resource_ids and not self.user_ids:
            return
        with self.repository._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    if self.resource_ids:
                        placeholders = ", ".join("%s" for _ in self.resource_ids)
                        resource_ids = tuple(self.resource_ids)
                        cursor.execute(
                            f"DELETE FROM resource_interactions WHERE resource_id IN ({placeholders})",
                            resource_ids,
                        )
                        cursor.execute(
                            f"DELETE FROM workshop_enrollments WHERE resource_id IN ({placeholders})",
                            resource_ids,
                        )
                        cursor.execute(
                            f"DELETE FROM support_resources WHERE id IN ({placeholders})",
                            resource_ids,
                        )
                    if self.user_ids:
                        placeholders = ", ".join("%s" for _ in self.user_ids)
                        cursor.execute(
                            f"DELETE FROM student_preferences WHERE user_id IN ({placeholders})",
                            tuple(self.user_ids),
                        )
                connection.commit()
            except Exception:
                connection.rollback()
                raise

    def _resource_data(self, resource_type: str) -> dict[str, Any]:
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        data: dict[str, Any] = {
            "resource_type": resource_type,
            "title": f"Integration {self.suffix}",
            "description": "Recurso temporal para integración con MySQL",
            "tags": [self.tag],
            "course_codes": [self.course_code],
            "modality": None,
            "location": None,
            "start_at": None,
            "end_at": None,
            "capacity": None,
            "url": f"https://example.org/{self.suffix}",
        }
        if resource_type in {"TUTORING", "WORKSHOP"}:
            data.update(
                {
                    "modality": "REMOTO",
                    "start_at": now + timedelta(days=7),
                    "end_at": now + timedelta(days=7, hours=1),
                    "url": None,
                }
            )
        if resource_type == "WORKSHOP":
            data["capacity"] = 1
        return data

    def _create_resource(self, resource_type: str, creator_user_id: int) -> dict[str, Any]:
        record = self.repository.create_resource(
            self._resource_data(resource_type), creator_user_id, "ADMINISTRADOR"
        )
        self.resource_ids.add(int(record["id"]))
        return record

    def test_resource_crud_filters_and_preferences_use_mysql(self) -> None:
        material = self._create_resource("MATERIAL", self.user_id)
        filtered, total = self.repository.list_resources(
            course_code=self.course_code, tag=self.tag
        )
        self.assertEqual(total, 1)
        self.assertEqual(filtered[0]["id"], material["id"])

        updated = self.repository.update_resource(
            int(material["id"]), {"title": "Título actualizado"}, self.user_id,
            "ADMINISTRADOR",
        )
        self.assertEqual(updated["title"], "Título actualizado")

        preferences = {
            "interests": [self.tag],
            "course_codes": [self.course_code],
            "available_slots": [],
            "preferred_modalities": ["REMOTO"],
            "time_zone": "America/Lima",
        }
        saved = self.repository.save_preferences(self.user_id, preferences)
        self.assertEqual(saved["interests"], preferences["interests"])
        self.assertEqual(self.repository.get_preferences(self.user_id)["course_codes"],
                         preferences["course_codes"])

        self.repository.cancel_resource(
            int(material["id"]), self.user_id, "ADMINISTRADOR"
        )
        self.assertIsNone(self.repository.get_published_resource(int(material["id"])))

    def test_concurrent_student_tutoring_creation_allows_only_one(self) -> None:
        data = self._resource_data("TUTORING")
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [
                executor.submit(
                    self.repository.create_resource, data, self.user_id, "ESTUDIANTE"
                )
                for _ in range(2)
            ]

        results: list[dict[str, Any]] = []
        conflicts = 0
        for future in futures:
            try:
                results.append(future.result())
            except ConflictError:
                conflicts += 1
        self.resource_ids.update(int(result["id"]) for result in results)
        self.assertEqual(len(results), 1)
        self.assertEqual(conflicts, 1)

    def test_concurrent_enrollment_cannot_take_the_last_seat_twice(self) -> None:
        workshop = self._create_resource("WORKSHOP", self.user_id)
        second_user_id = self.user_id + 1
        self.user_ids.add(second_user_id)
        with ThreadPoolExecutor(max_workers=2) as executor:
            futures = [
                executor.submit(
                    self.repository.enroll_in_workshop, attendee_id, int(workshop["id"])
                )
                for attendee_id in (self.user_id, second_user_id)
            ]

        successes = 0
        conflicts = 0
        for future in futures:
            try:
                future.result()
                successes += 1
            except ConflictError:
                conflicts += 1
        current = self.repository.get_published_resource(int(workshop["id"]))
        self.assertEqual(successes, 1)
        self.assertEqual(conflicts, 1)
        self.assertEqual(current["available_seats"], 0)


if __name__ == "__main__":
    unittest.main()

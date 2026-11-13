from __future__ import annotations

import os
import unittest
import uuid
from pathlib import Path

from dotenv import load_dotenv

from src.config import Settings
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
class MySqlLiveIntegrationTests(unittest.TestCase):
    def test_connection_required_schema_and_collation(self) -> None:
        settings = Settings.from_environment()
        repository = MySqlAcademicSupportRepository(settings)
        required_tables = {
            "student_preferences",
            "support_resources",
            "workshop_enrollments",
            "resource_interactions",
        }

        with repository._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT DATABASE() AS database_name")
                self.assertEqual(cursor.fetchone()["database_name"], settings.db_name)
                cursor.execute(
                    """
                    SELECT TABLE_NAME, TABLE_COLLATION
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = DATABASE()
                    """
                )
                table_collations = {
                    row["TABLE_NAME"]: row["TABLE_COLLATION"]
                    for row in cursor.fetchall()
                }

        self.assertTrue(
            required_tables.issubset(table_collations),
            f"Faltan tablas del esquema: {sorted(required_tables - set(table_collations))}",
        )
        self.assertEqual(
            {table_collations[table] for table in required_tables},
            {"utf8mb4_0900_ai_ci"},
            "Las tablas deben usar la colación definida actualmente en schema.sql",
        )

    def test_database_supports_advisory_lock_used_for_unique_tutoring(self) -> None:
        settings = Settings.from_environment()
        repository = MySqlAcademicSupportRepository(settings)
        lock_name = f"g7-as-live-check-{uuid.uuid4().hex}"

        with repository._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT GET_LOCK(%s, 5) AS acquired", (lock_name,))
                self.assertEqual(cursor.fetchone()["acquired"], 1)
                cursor.execute("SELECT RELEASE_LOCK(%s) AS released", (lock_name,))
                self.assertEqual(cursor.fetchone()["released"], 1)


if __name__ == "__main__":
    unittest.main()

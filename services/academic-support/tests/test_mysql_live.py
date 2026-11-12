from __future__ import annotations

import os
import unittest
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
    def test_connection_and_required_schema(self) -> None:
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
                    SELECT TABLE_NAME
                    FROM INFORMATION_SCHEMA.TABLES
                    WHERE TABLE_SCHEMA = DATABASE()
                    """
                )
                actual_tables = {row["TABLE_NAME"] for row in cursor.fetchall()}

        self.assertTrue(
            required_tables.issubset(actual_tables),
            f"Faltan tablas del esquema: {sorted(required_tables - actual_tables)}",
        )


if __name__ == "__main__":
    unittest.main()

from __future__ import annotations

import ssl
import unittest
from unittest.mock import MagicMock, patch

from src.config import Settings
from src.infrastructure.mysql_repository import MySqlAcademicSupportRepository


BASE_ENV = {
    "DB_HOST": "mysql.example.test",
    "DB_NAME": "academic_support",
    "DB_USER": "academic_support_app",
    "DB_PASSWORD": "test-only-password",
    "JWT_SECRET": "test-only-jwt-secret-long-enough",
}


class MySqlConnectionConfigurationTests(unittest.TestCase):
    def test_ssl_is_disabled_by_default_for_local_development(self) -> None:
        with patch.dict("os.environ", BASE_ENV, clear=True):
            settings = Settings.from_environment()

        self.assertFalse(settings.db_ssl)
        self.assertIsNone(settings.db_ssl_ca)

    def test_ssl_and_private_ca_are_read_from_environment(self) -> None:
        environment = {**BASE_ENV, "DB_SSL": "true", "DB_SSL_CA": "C:/certs/mysql-ca.pem"}
        with patch.dict("os.environ", environment, clear=True):
            settings = Settings.from_environment()

        self.assertTrue(settings.db_ssl)
        self.assertEqual(settings.db_ssl_ca, "C:/certs/mysql-ca.pem")

    def test_invalid_ssl_value_fails_fast(self) -> None:
        environment = {**BASE_ENV, "DB_SSL": "sometimes"}
        with patch.dict("os.environ", environment, clear=True):
            with self.assertRaisesRegex(RuntimeError, "DB_SSL"):
                Settings.from_environment()

    def test_tls_connection_uses_certificate_and_hostname_validation(self) -> None:
        settings = Settings(
            port=5003,
            db_host="mysql.example.test",
            db_port=3306,
            db_name="academic_support",
            db_user="academic_support_app",
            db_password="test-only-password",
            jwt_secret="test-only-jwt-secret-long-enough",
            db_ssl=True,
        )
        repository = MySqlAcademicSupportRepository(settings)
        fake_connection = MagicMock()

        with patch(
            "src.infrastructure.mysql_repository.pymysql.connect",
            return_value=fake_connection,
        ) as connect:
            with repository._connect() as connection:
                self.assertIs(connection, fake_connection)

        self.assertIsInstance(repository._ssl_context, ssl.SSLContext)
        self.assertTrue(repository._ssl_context.check_hostname)
        self.assertEqual(repository._ssl_context.verify_mode, ssl.CERT_REQUIRED)
        self.assertIs(connect.call_args.kwargs["ssl"], repository._ssl_context)
        fake_connection.close.assert_called_once()

    def test_saving_preferences_reuses_its_database_connection(self) -> None:
        settings = Settings(
            port=5003,
            db_host="mysql.example.test",
            db_port=3306,
            db_name="academic_support",
            db_user="academic_support_app",
            db_password="test-only-password",
            jwt_secret="test-only-jwt-secret-long-enough",
        )
        repository = MySqlAcademicSupportRepository(settings)
        fake_connection = MagicMock()
        cursor = fake_connection.cursor.return_value.__enter__.return_value
        cursor.fetchone.return_value = {
            "interests": '["programación"]',
            "course_codes": "[]",
            "available_slots": "[]",
            "preferred_modalities": '["REMOTO"]',
            "time_zone": "America/Lima",
            "updated_at": None,
        }
        preferences = {
            "interests": ["programación"],
            "course_codes": [],
            "available_slots": [],
            "preferred_modalities": ["REMOTO"],
            "time_zone": "America/Lima",
        }

        with patch(
            "src.infrastructure.mysql_repository.pymysql.connect",
            return_value=fake_connection,
        ) as connect:
            saved = repository.save_preferences(17, preferences)

        self.assertEqual(saved["interests"], ["programación"])
        self.assertEqual(saved["preferred_modalities"], ["REMOTO"])
        self.assertEqual(connect.call_count, 1)
        self.assertEqual(cursor.execute.call_count, 2)
        fake_connection.commit.assert_called_once()
        fake_connection.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()

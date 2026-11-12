from __future__ import annotations

import json
import ssl
from contextlib import contextmanager
from datetime import datetime, timezone
from typing import Any, Iterator

import pymysql
from pymysql.cursors import DictCursor

from ..config import Settings
from ..domain.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError


RESOURCE_FIELDS = {
    "title": "title",
    "description": "description",
    "tags": "tags",
    "course_codes": "course_codes",
    "modality": "modality",
    "location": "location",
    "start_at": "start_at",
    "end_at": "end_at",
    "capacity": "capacity",
    "url": "url",
}

RESOURCE_SELECT = """
    SELECT
        r.id, r.resource_type, r.title, r.description, r.tags, r.course_codes,
        r.modality, r.location, r.start_at, r.end_at, r.capacity, r.url,
        r.creator_user_id, r.status, r.is_synthetic, r.created_at, r.updated_at,
        CASE
            WHEN r.capacity IS NULL THEN NULL
            ELSE GREATEST(
                r.capacity - (
                    SELECT COUNT(*)
                    FROM workshop_enrollments e
                    WHERE e.resource_id = r.id AND e.status = 'ACTIVE'
                ),
                0
            )
        END AS available_seats
    FROM support_resources r
"""

PREFERENCE_SELECT = """
    SELECT interests, course_codes, available_slots, preferred_modalities, time_zone, updated_at
    FROM student_preferences
    WHERE user_id = %s
"""


class MySqlAcademicSupportRepository:
    def __init__(self, settings: Settings):
        self._settings = settings
        self._ssl_context = (
            ssl.create_default_context(cafile=settings.db_ssl_ca)
            if settings.db_ssl
            else None
        )

    @contextmanager
    def _connect(self) -> Iterator[pymysql.connections.Connection]:
        connection = pymysql.connect(
            host=self._settings.db_host,
            port=self._settings.db_port,
            user=self._settings.db_user,
            password=self._settings.db_password,
            database=self._settings.db_name,
            charset="utf8mb4",
            cursorclass=DictCursor,
            autocommit=False,
            connect_timeout=5,
            read_timeout=10,
            write_timeout=10,
            init_command="SET time_zone = '+00:00'",
            ssl=self._ssl_context,
        )
        try:
            yield connection
        finally:
            connection.close()

    @staticmethod
    def _decode_json(value: Any, fallback: Any) -> Any:
        if value is None:
            return fallback
        if isinstance(value, (dict, list)):
            return value
        if isinstance(value, bytes):
            value = value.decode("utf-8")
        try:
            return json.loads(value)
        except (TypeError, ValueError):
            return fallback

    @classmethod
    def _decode_resource(cls, row: dict[str, Any]) -> dict[str, Any]:
        result = dict(row)
        result["tags"] = cls._decode_json(result.get("tags"), [])
        result["course_codes"] = cls._decode_json(result.get("course_codes"), [])
        result["is_synthetic"] = bool(result.get("is_synthetic"))
        return result

    @staticmethod
    def _json(value: Any) -> str:
        return json.dumps(value, ensure_ascii=False, separators=(",", ":"))

    @classmethod
    def _decode_preferences(
        cls, user_id: int, row: dict[str, Any] | None
    ) -> dict[str, Any]:
        if row is None:
            return {
                "user_id": user_id,
                "interests": [],
                "course_codes": [],
                "available_slots": [],
                "preferred_modalities": [],
                "time_zone": "America/Lima",
            }
        return {
            "user_id": user_id,
            "interests": cls._decode_json(row["interests"], []),
            "course_codes": cls._decode_json(row["course_codes"], []),
            "available_slots": cls._decode_json(row["available_slots"], []),
            "preferred_modalities": cls._decode_json(row["preferred_modalities"], []),
            "time_zone": row["time_zone"],
            "updated_at": row["updated_at"],
        }

    def ping(self) -> bool:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1 AS ok")
                return bool(cursor.fetchone()["ok"])

    def get_preferences(self, user_id: int) -> dict[str, Any]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(PREFERENCE_SELECT, (user_id,))
                row = cursor.fetchone()
        return self._decode_preferences(user_id, row)

    def save_preferences(self, user_id: int, preferences: dict[str, Any]) -> dict[str, Any]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    INSERT INTO student_preferences
                        (user_id, interests, course_codes, available_slots, preferred_modalities, time_zone)
                    VALUES (%s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                        interests = VALUES(interests),
                        course_codes = VALUES(course_codes),
                        available_slots = VALUES(available_slots),
                        preferred_modalities = VALUES(preferred_modalities),
                        time_zone = VALUES(time_zone)
                    """,
                    (
                        user_id,
                        self._json(preferences["interests"]),
                        self._json(preferences["course_codes"]),
                        self._json(preferences["available_slots"]),
                        self._json(preferences["preferred_modalities"]),
                        preferences["time_zone"],
                    ),
                )
                cursor.execute(PREFERENCE_SELECT, (user_id,))
                row = cursor.fetchone()
            connection.commit()
        return self._decode_preferences(user_id, row)

    def list_resources(
        self,
        resource_type: str | None = None,
        course_code: str | None = None,
        tag: str | None = None,
        limit: int = 20,
        offset: int = 0,
    ) -> tuple[list[dict[str, Any]], int]:
        conditions = [
            "r.status = 'PUBLISHED'",
            "(r.end_at IS NULL OR r.end_at > UTC_TIMESTAMP())",
        ]
        params: list[Any] = []
        if resource_type:
            conditions.append("r.resource_type = %s")
            params.append(resource_type)
        if course_code:
            conditions.append("JSON_CONTAINS(r.course_codes, JSON_QUOTE(%s))")
            params.append(course_code)
        if tag:
            conditions.append("JSON_CONTAINS(r.tags, JSON_QUOTE(%s))")
            params.append(tag)

        where_sql = " WHERE " + " AND ".join(conditions)
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT COUNT(*) AS total FROM support_resources r" + where_sql,
                    tuple(params),
                )
                total = int(cursor.fetchone()["total"])
                cursor.execute(
                    RESOURCE_SELECT
                    + where_sql
                    + " ORDER BY r.start_at IS NULL, r.start_at ASC, r.id DESC LIMIT %s OFFSET %s",
                    tuple(params + [limit, offset]),
                )
                rows = cursor.fetchall()
        return [self._decode_resource(row) for row in rows], total

    def get_published_resource(self, resource_id: int) -> dict[str, Any] | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    RESOURCE_SELECT + " WHERE r.id = %s AND r.status = 'PUBLISHED'",
                    (resource_id,),
                )
                row = cursor.fetchone()
        return self._decode_resource(row) if row else None

    def get_resource_record(self, resource_id: int) -> dict[str, Any] | None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(RESOURCE_SELECT + " WHERE r.id = %s", (resource_id,))
                row = cursor.fetchone()
        return self._decode_resource(row) if row else None

    def create_resource(
        self, data: dict[str, Any], creator_user_id: int, creator_role: str
    ) -> dict[str, Any]:
        with self._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    if creator_role == "ESTUDIANTE" and data["resource_type"] == "TUTORING":
                        # Serialize concurrent creates by the same student across service instances.
                        lock_name = f"g7-as-tutoring-{creator_user_id}"
                        cursor.execute("SELECT GET_LOCK(%s, 5) AS acquired", (lock_name,))
                        if cursor.fetchone()["acquired"] != 1:
                            raise ConflictError(
                                "No se pudo validar tu oferta de tutoría; vuelve a intentarlo"
                            )
                        cursor.execute(
                            """
                            SELECT id
                            FROM support_resources
                            WHERE creator_user_id = %s
                              AND resource_type = 'TUTORING'
                              AND status = 'PUBLISHED'
                            LIMIT 1
                            """,
                            (creator_user_id,),
                        )
                        if cursor.fetchone() is not None:
                            raise ConflictError(
                                "Ya tienes una tutoría publicada; cancélala antes de crear otra"
                            )

                    cursor.execute(
                        """
                        INSERT INTO support_resources
                            (resource_type, title, description, tags, course_codes, modality,
                             location, start_at, end_at, capacity, url, creator_user_id,
                             status, is_synthetic)
                        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 'PUBLISHED', FALSE)
                        """,
                        (
                            data["resource_type"],
                            data["title"],
                            data["description"],
                            self._json(data["tags"]),
                            self._json(data["course_codes"]),
                            data["modality"],
                            data["location"],
                            data["start_at"],
                            data["end_at"],
                            data["capacity"],
                            data["url"],
                            creator_user_id,
                        ),
                    )
                    resource_id = int(cursor.lastrowid)
                connection.commit()
            except Exception:
                connection.rollback()
                raise
        resource = self.get_resource_record(resource_id)
        if resource is None:
            raise NotFoundError("No se pudo recuperar el recurso creado")
        return resource

    def update_resource(
        self,
        resource_id: int,
        data: dict[str, Any],
        actor_user_id: int,
        actor_role: str,
    ) -> dict[str, Any]:
        with self._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        SELECT id, resource_type, creator_user_id
                        FROM support_resources
                        WHERE id = %s
                        FOR UPDATE
                        """,
                        (resource_id,),
                    )
                    existing = cursor.fetchone()
                    if existing is None:
                        raise NotFoundError("No se encontró el recurso")
                    is_staff = actor_role in {"PERSONAL_UNAYOE", "ADMINISTRADOR"}
                    is_owner_tutor = (
                        existing["resource_type"] == "TUTORING"
                        and int(existing["creator_user_id"]) == actor_user_id
                    )
                    if not (is_staff or is_owner_tutor):
                        raise ForbiddenError("No tienes permiso para editar este recurso")

                    if "capacity" in data and data["capacity"] is not None:
                        cursor.execute(
                            """
                            SELECT COUNT(*) AS active_count
                            FROM workshop_enrollments
                            WHERE resource_id = %s AND status = 'ACTIVE'
                            """,
                            (resource_id,),
                        )
                        active_count = int(cursor.fetchone()["active_count"])
                        if data["capacity"] < active_count:
                            raise ConflictError(
                                "La capacidad no puede ser menor que las inscripciones activas"
                            )

                    assignments: list[str] = []
                    values: list[Any] = []
                    for request_key, column in RESOURCE_FIELDS.items():
                        if request_key not in data:
                            continue
                        value = data[request_key]
                        assignments.append(f"{column} = %s")
                        values.append(
                            self._json(value)
                            if request_key in {"tags", "course_codes"}
                            else value
                        )
                    if assignments:
                        cursor.execute(
                            "UPDATE support_resources SET "
                            + ", ".join(assignments)
                            + " WHERE id = %s",
                            tuple(values + [resource_id]),
                        )
                connection.commit()
            except Exception:
                connection.rollback()
                raise

        resource = self.get_resource_record(resource_id)
        if resource is None:
            raise NotFoundError("No se encontró el recurso")
        return resource

    def cancel_resource(
        self, resource_id: int, actor_user_id: int, actor_role: str
    ) -> None:
        with self._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        SELECT resource_type, creator_user_id
                        FROM support_resources
                        WHERE id = %s
                        FOR UPDATE
                        """,
                        (resource_id,),
                    )
                    existing = cursor.fetchone()
                    if existing is None:
                        raise NotFoundError("No se encontró el recurso")
                    is_staff = actor_role in {"PERSONAL_UNAYOE", "ADMINISTRADOR"}
                    is_owner_tutor = (
                        existing["resource_type"] == "TUTORING"
                        and int(existing["creator_user_id"]) == actor_user_id
                    )
                    if not (is_staff or is_owner_tutor):
                        raise ForbiddenError("No tienes permiso para cancelar este recurso")
                    cursor.execute(
                        """
                        UPDATE support_resources
                        SET status = 'CANCELLED'
                        WHERE id = %s AND status = 'PUBLISHED'
                        """,
                        (resource_id,),
                    )
                    cursor.execute(
                        """
                        UPDATE workshop_enrollments
                        SET status = 'CANCELLED'
                        WHERE resource_id = %s AND status = 'ACTIVE'
                        """,
                        (resource_id,),
                    )
                connection.commit()
            except Exception:
                connection.rollback()
                raise

    def get_recommendation_inputs(
        self, user_id: int
    ) -> tuple[list[dict[str, Any]], dict[str, Any], list[dict[str, Any]], set[int]]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(PREFERENCE_SELECT, (user_id,))
                preferences = self._decode_preferences(user_id, cursor.fetchone())
                cursor.execute(
                    RESOURCE_SELECT
                    + """
                    WHERE r.status = 'PUBLISHED'
                      AND (r.end_at IS NULL OR r.end_at > UTC_TIMESTAMP())
                      AND (r.capacity IS NULL OR r.capacity > (
                          SELECT COUNT(*)
                          FROM workshop_enrollments e
                          WHERE e.resource_id = r.id AND e.status = 'ACTIVE'
                      ))
                    ORDER BY r.id DESC
                    LIMIT 2000
                    """
                )
                resources = [self._decode_resource(row) for row in cursor.fetchall()]
                cursor.execute(
                    """
                    SELECT resource_id
                    FROM workshop_enrollments
                    WHERE user_id = %s AND status = 'ACTIVE'
                    """,
                    (user_id,),
                )
                enrolled_ids = {int(row["resource_id"]) for row in cursor.fetchall()}
                cursor.execute(
                    """
                    SELECT id, user_id, resource_id, event_type, created_at
                    FROM resource_interactions
                    WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 180 DAY
                    ORDER BY created_at DESC, id DESC
                    LIMIT 50000
                    """
                )
                interactions = [
                    {
                        "user_id": int(row["user_id"]),
                        "resource_id": int(row["resource_id"]),
                        "event_type": row["event_type"],
                        "created_at": row["created_at"],
                    }
                    for row in cursor.fetchall()
                ]
        resources = [row for row in resources if int(row["id"]) not in enrolled_ids]
        return resources, preferences, interactions, enrolled_ids

    def record_interaction(
        self, user_id: int, resource_id: int, event_type: str
    ) -> None:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    "SELECT id, status FROM support_resources WHERE id = %s",
                    (resource_id,),
                )
                resource = cursor.fetchone()
                if resource is None:
                    raise NotFoundError("No se encontró el recurso")
                if resource["status"] != "PUBLISHED":
                    raise ConflictError("El recurso ya no está disponible")
                cursor.execute(
                    """
                    INSERT INTO resource_interactions (user_id, resource_id, event_type)
                    VALUES (%s, %s, %s)
                    """,
                    (user_id, resource_id, event_type),
                )
            connection.commit()

    def enroll_in_workshop(self, user_id: int, resource_id: int) -> dict[str, Any]:
        with self._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        SELECT id, resource_type, status, capacity, end_at
                        FROM support_resources
                        WHERE id = %s
                        FOR UPDATE
                        """,
                        (resource_id,),
                    )
                    resource = cursor.fetchone()
                    if resource is None:
                        raise NotFoundError("No se encontró el taller")
                    if resource["resource_type"] != "WORKSHOP":
                        raise ValidationError("El recurso indicado no es un taller")
                    if resource["status"] != "PUBLISHED":
                        raise ConflictError("El taller ya no está disponible")
                    if (
                        resource["end_at"] is not None
                        and resource["end_at"].replace(tzinfo=timezone.utc)
                        <= datetime.now(timezone.utc)
                    ):
                        raise ConflictError("El taller ya finalizó")

                    cursor.execute(
                        """
                        SELECT id, status
                        FROM workshop_enrollments
                        WHERE user_id = %s AND resource_id = %s
                        FOR UPDATE
                        """,
                        (user_id, resource_id),
                    )
                    existing = cursor.fetchone()
                    if existing and existing["status"] == "ACTIVE":
                        raise ConflictError("Ya tienes una inscripción activa en este taller")

                    cursor.execute(
                        """
                        SELECT COUNT(*) AS active_count
                        FROM workshop_enrollments
                        WHERE resource_id = %s AND status = 'ACTIVE'
                        """,
                        (resource_id,),
                    )
                    active_count = int(cursor.fetchone()["active_count"])
                    if resource["capacity"] is not None and active_count >= int(resource["capacity"]):
                        raise ConflictError("El taller ya no tiene cupos disponibles")

                    if existing:
                        cursor.execute(
                            """
                            UPDATE workshop_enrollments
                            SET status = 'ACTIVE', enrolled_at = UTC_TIMESTAMP()
                            WHERE id = %s
                            """,
                            (existing["id"],),
                        )
                    else:
                        cursor.execute(
                            """
                            INSERT INTO workshop_enrollments (resource_id, user_id, status)
                            VALUES (%s, %s, 'ACTIVE')
                            """,
                            (resource_id, user_id),
                        )
                    cursor.execute(
                        """
                        INSERT INTO resource_interactions (user_id, resource_id, event_type)
                        VALUES (%s, %s, 'ENROLL')
                        """,
                        (user_id, resource_id),
                    )
                    cursor.execute(
                        """
                        SELECT id, resource_id, user_id, status, enrolled_at
                        FROM workshop_enrollments
                        WHERE user_id = %s AND resource_id = %s
                        """,
                        (user_id, resource_id),
                    )
                    enrollment = cursor.fetchone()
                connection.commit()
            except Exception:
                connection.rollback()
                raise
        return {
            "id": int(enrollment["id"]),
            "resourceId": int(enrollment["resource_id"]),
            "userId": int(enrollment["user_id"]),
            "status": enrollment["status"],
            "enrolledAt": self._iso_utc(enrollment["enrolled_at"]),
        }

    def cancel_workshop_enrollment(self, user_id: int, resource_id: int) -> None:
        with self._connect() as connection:
            try:
                with connection.cursor() as cursor:
                    cursor.execute(
                        """
                        SELECT id, status
                        FROM workshop_enrollments
                        WHERE user_id = %s AND resource_id = %s
                        FOR UPDATE
                        """,
                        (user_id, resource_id),
                    )
                    enrollment = cursor.fetchone()
                    if enrollment is None or enrollment["status"] != "ACTIVE":
                        raise NotFoundError("No tienes una inscripción activa en este taller")
                    cursor.execute(
                        "UPDATE workshop_enrollments SET status = 'CANCELLED' WHERE id = %s",
                        (enrollment["id"],),
                    )
                    cursor.execute(
                        """
                        INSERT INTO resource_interactions (user_id, resource_id, event_type)
                        VALUES (%s, %s, 'WITHDRAW')
                        """,
                        (user_id, resource_id),
                    )
                connection.commit()
            except Exception:
                connection.rollback()
                raise

    def list_user_enrollments(self, user_id: int) -> list[dict[str, Any]]:
        with self._connect() as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        e.id, e.resource_id, e.status, e.enrolled_at,
                        r.title, r.description, r.start_at, r.end_at, r.location,
                        r.modality, r.capacity,
                        GREATEST(
                            r.capacity - (
                                SELECT COUNT(*)
                                FROM workshop_enrollments active_e
                                WHERE active_e.resource_id = r.id
                                  AND active_e.status = 'ACTIVE'
                            ),
                            0
                        ) AS available_seats
                    FROM workshop_enrollments e
                    INNER JOIN support_resources r ON r.id = e.resource_id
                    WHERE e.user_id = %s AND e.status = 'ACTIVE'
                    ORDER BY e.enrolled_at DESC
                    """,
                    (user_id,),
                )
                rows = cursor.fetchall()
        return [
            {
                "id": int(row["id"]),
                "resourceId": int(row["resource_id"]),
                "status": row["status"],
                "enrolledAt": self._iso_utc(row["enrolled_at"]),
                "workshop": {
                    "id": int(row["resource_id"]),
                    "title": row["title"],
                    "description": row["description"],
                    "startAt": self._iso_utc(row["start_at"]),
                    "endAt": self._iso_utc(row["end_at"]),
                    "location": row["location"],
                    "modality": row["modality"],
                    "capacity": row["capacity"],
                    "availableSeats": row["available_seats"],
                },
            }
            for row in rows
        ]

    @staticmethod
    def _iso_utc(value: Any) -> str | None:
        if value is None:
            return None
        if value.tzinfo is None:
            value = value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")

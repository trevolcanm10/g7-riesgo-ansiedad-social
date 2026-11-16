from typing import List, Optional
from datetime import date, datetime

from ...domain.entities.academic_activity import AcademicActivity
from ...domain.repositories.activity_repository import ActivityRepository
from ...domain.errors import ActivityNotFoundError
from ..persistence.mysql_database import MySQLDatabase


class MySqlActivityRepository(ActivityRepository):
    """Implementación MySQL del repositorio de actividades."""

    def __init__(self, db: MySQLDatabase) -> None:
        self.db = db

    def create(self, activity: AcademicActivity) -> AcademicActivity:
        conn = self.db.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO actividades_academicas
                      (user_id, title, course, activity_type, activity_date,
                       estimated_hours, priority, description, completed)
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        activity.user_id,
                        activity.title,
                        activity.course,
                        activity.activity_type,
                        activity.activity_date,
                        activity.estimated_hours,
                        activity.priority,
                        activity.description,
                        activity.completed,
                    ),
                )
                activity.id = cur.lastrowid
        finally:
            conn.close()
        return activity

    def get_by_id(
        self, activity_id: int, user_id: int
    ) -> Optional[AcademicActivity]:
        conn = self.db.get_connection()
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute(
                    """
                    SELECT id, user_id, title, course, activity_type, activity_date,
                           estimated_hours, priority, description, completed, created_at
                    FROM actividades_academicas
                    WHERE id = %s AND user_id = %s
                    """,
                    (activity_id, user_id),
                )
                row = cur.fetchone()
        finally:
            conn.close()
        if not row:
            raise ActivityNotFoundError(
                f"Actividad {activity_id} no encontrada para el usuario {user_id}"
            )
        return self._row_to_entity(row)

    def list_by_user(self, user_id: int) -> List[AcademicActivity]:
        conn = self.db.get_connection()
        try:
            with conn.cursor(dictionary=True) as cur:
                cur.execute(
                    """
                    SELECT id, user_id, title, course, activity_type, activity_date,
                           estimated_hours, priority, description, completed, created_at
                    FROM actividades_academicas
                    WHERE user_id = %s
                    ORDER BY activity_date ASC, created_at DESC
                    """,
                    (user_id,),
                )
                rows = cur.fetchall()
        finally:
            conn.close()
        return [self._row_to_entity(row) for row in rows]

    def update(
        self, activity_id: int, user_id: int, updates: dict
    ) -> Optional[AcademicActivity]:
        # Verificar existencia y pertenencia
        existing = self.get_by_id(activity_id, user_id)
        if not existing:
            return None

        allowed = {
            "title": "title",
            "course": "course",
            "activity_type": "activity_type",
            "activity_date": "activity_date",
            "estimated_hours": "estimated_hours",
            "priority": "priority",
            "description": "description",
            "completed": "completed",
        }
        assignments = []
        values = []
        for key, column in allowed.items():
            if key in updates and updates[key] is not None:
                assignments.append(f"{column} = %s")
                values.append(updates[key])
        if not assignments:
            return existing

        values.extend([activity_id, user_id])
        conn = self.db.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    f"UPDATE actividades_academicas SET {', '.join(assignments)} "
                    "WHERE id = %s AND user_id = %s",
                    values,
                )
        finally:
            conn.close()
        return self.get_by_id(activity_id, user_id)

    def delete(self, activity_id: int, user_id: int) -> bool:
        existing = self.get_by_id(activity_id, user_id)
        if not existing:
            return False
        conn = self.db.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "DELETE FROM actividades_academicas WHERE id = %s AND user_id = %s",
                    (activity_id, user_id),
                )
                deleted = cur.rowcount > 0
        finally:
            conn.close()
        return deleted

    @staticmethod
    def _row_to_entity(row: dict) -> AcademicActivity:
        return AcademicActivity(
            id=row["id"],
            user_id=row["user_id"],
            title=row["title"],
            course=row["course"],
            activity_type=row["activity_type"],
            activity_date=row["activity_date"],
            estimated_hours=float(row["estimated_hours"]),
            priority=row["priority"],
            description=row["description"] or "",
            completed=bool(row["completed"]),
            created_at=row["created_at"],
        )
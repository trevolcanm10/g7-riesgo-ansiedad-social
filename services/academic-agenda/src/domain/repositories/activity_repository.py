from abc import ABC, abstractmethod
from typing import List, Optional
from ..entities.academic_activity import AcademicActivity


class ActivityRepository(ABC):
    """Puerto de repositorio para actividades académicas."""

    @abstractmethod
    def create(self, activity: AcademicActivity) -> AcademicActivity:
        """Crea una actividad y la devuelve con su ID asignado."""

    @abstractmethod
    def get_by_id(self, activity_id: int, user_id: int) -> Optional[AcademicActivity]:
        """Obtiene una actividad por ID perteneciente al usuario."""

    @abstractmethod
    def list_by_user(self, user_id: int) -> List[AcademicActivity]:
        """Lista todas las actividades de un usuario."""

    @abstractmethod
    def update(
        self, activity_id: int, user_id: int, updates: dict
    ) -> Optional[AcademicActivity]:
        """Actualiza campos de una actividad si pertenece al usuario."""

    @abstractmethod
    def delete(self, activity_id: int, user_id: int) -> bool:
        """Elimina una actividad si pertenece al usuario. Devuelve si se eliminó."""
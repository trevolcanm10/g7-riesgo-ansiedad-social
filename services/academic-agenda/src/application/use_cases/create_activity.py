from ...domain.entities.academic_activity import AcademicActivity
from ...domain.repositories.activity_repository import ActivityRepository
from ...domain.errors import InvalidActivityError
from datetime import date


class CreateActivityUseCase:
    def __init__(self, repository: ActivityRepository) -> None:
        self.repository = repository

    def execute(
        self,
        user_id: int,
        title: str,
        course: str,
        activity_type: str,
        activity_date: date,
        estimated_hours: float,
        priority: str,
        description: str,
        completed: bool = False,
    ) -> AcademicActivity:
        activity = AcademicActivity(
            id=None,
            user_id=user_id,
            title=title.strip(),
            course=course.strip(),
            activity_type=activity_type,
            activity_date=activity_date,
            estimated_hours=estimated_hours,
            priority=priority,
            description=description.strip(),
            completed=completed,
        )
        try:
            return self.repository.create(activity)
        except ValueError as exc:
            raise InvalidActivityError(str(exc)) from exc
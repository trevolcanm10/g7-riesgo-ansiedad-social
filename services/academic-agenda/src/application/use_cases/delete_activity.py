from ...domain.repositories.activity_repository import ActivityRepository


class DeleteActivityUseCase:
    def __init__(self, repository: ActivityRepository) -> None:
        self.repository = repository

    def execute(self, activity_id: int, user_id: int) -> bool:
        return self.repository.delete(activity_id, user_id)
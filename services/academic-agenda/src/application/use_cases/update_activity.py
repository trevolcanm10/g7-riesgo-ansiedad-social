from ...domain.repositories.activity_repository import ActivityRepository


class UpdateActivityUseCase:
    def __init__(self, repository: ActivityRepository) -> None:
        self.repository = repository

    def execute(self, activity_id: int, user_id: int, updates: dict):
        return self.repository.update(activity_id, user_id, updates)
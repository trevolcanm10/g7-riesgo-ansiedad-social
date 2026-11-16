from ...domain.repositories.activity_repository import ActivityRepository


class ListActivitiesUseCase:
    def __init__(self, repository: ActivityRepository) -> None:
        self.repository = repository

    def execute(self, user_id: int):
        return self.repository.list_by_user(user_id)
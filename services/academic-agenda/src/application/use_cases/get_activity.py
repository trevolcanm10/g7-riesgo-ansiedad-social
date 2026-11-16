from ...domain.repositories.activity_repository import ActivityRepository


class GetActivityUseCase:
    def __init__(self, repository: ActivityRepository) -> None:
        self.repository = repository

    def execute(self, activity_id: int, user_id: int):
        return self.repository.get_by_id(activity_id, user_id)
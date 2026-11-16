import pytest
from datetime import date

from src.application.use_cases.create_activity import CreateActivityUseCase
from src.application.use_cases.classify_week import ClassifyWeekUseCase
from src.application.use_cases.delete_activity import DeleteActivityUseCase
from src.domain.entities.academic_activity import AcademicActivity
from src.domain.errors import InvalidActivityError, ModelsUnavailableError


class FakeRepository:
    def __init__(self):
        self._store = {}
        self._next_id = 1

    def create(self, activity):
        activity.id = self._next_id
        self._next_id += 1
        self._store[activity.id] = activity
        return activity

    def get_by_id(self, activity_id, user_id):
        a = self._store.get(activity_id)
        if a and a.user_id == user_id:
            return a
        return None

    def list_by_user(self, user_id):
        return [a for a in self._store.values() if a.user_id == user_id]

    def update(self, activity_id, user_id, updates):
        a = self._store.get(activity_id)
        if not a or a.user_id != user_id:
            return None
        for k, v in updates.items():
            if hasattr(a, k):
                setattr(a, k, v)
        return a

    def delete(self, activity_id, user_id):
        a = self._store.get(activity_id)
        if a and a.user_id == user_id:
            del self._store[activity_id]
            return True
        return False


class FakeClassifier:
    def __init__(self, available=True):
        self._available = available

    @property
    def is_available(self):
        return self._available

    def classify_week(self, indicators):
        if not self._available:
            raise ModelsUnavailableError("no disponible")
        return {"nivel_carga": "MEDIO", "probabilidad_sobrecarga": 0.5}


def test_create_and_list_activity():
    repo = FakeRepository()
    uc = CreateActivityUseCase(repo)
    a = uc.execute(
        user_id=1, title="Tarea", course="Math", activity_type="tarea",
        activity_date=date(2026, 11, 15), estimated_hours=2.0,
        priority="media", description="hacer tarea",
    )
    assert a.id == 1
    assert a.user_id == 1

    list_uc = __import__(
        "src.application.use_cases.list_activities", fromlist=["ListActivitiesUseCase"]
    ).ListActivitiesUseCase(repo)
    acts = list_uc.execute(1)
    assert len(acts) == 1
    assert acts[0].title == "Tarea"


def test_get_and_update_activity():
    repo = FakeRepository()
    create_uc = CreateActivityUseCase(repo)
    a = create_uc.execute(
        user_id=1, title="T", course="C", activity_type="tarea",
        activity_date=date.today(), estimated_hours=1.0,
        priority="baja", description="d",
    )
    get_uc = __import__(
        "src.application.use_cases.get_activity", fromlist=["GetActivityUseCase"]
    ).GetActivityUseCase(repo)
    fetched = get_uc.execute(a.id, 1)
    assert fetched.id == a.id

    update_uc = __import__(
        "src.application.use_cases.update_activity", fromlist=["UpdateActivityUseCase"]
    ).UpdateActivityUseCase(repo)
    updated = update_uc.execute(a.id, 1, {"priority": "alta"})
    assert updated.priority == "alta"

    # Otro usuario no puede actualizar
    updated2 = update_uc.execute(a.id, 999, {"priority": "alta"})
    assert updated2 is None


def test_delete_activity():
    repo = FakeRepository()
    create_uc = CreateActivityUseCase(repo)
    a = create_uc.execute(
        user_id=1, title="T", course="C", activity_type="tarea",
        activity_date=date.today(), estimated_hours=1.0,
        priority="baja", description="d",
    )
    delete_uc = DeleteActivityUseCase(repo)
    assert delete_uc.execute(a.id, 1) is True
    assert delete_uc.execute(a.id, 1) is False  # ya no existe


def test_classify_week_available():
    classifier = FakeClassifier(available=True)
    uc = ClassifyWeekUseCase(classifier)
    result = uc.execute({
        "hours_studied": 10, "hours_sleep": 7, "hours_exercise": 3,
        "social_hours": 5, "stress_level": 6, "gpa": 3.5, "screen_hours": 4,
    })
    assert result["nivel_carga"] == "MEDIO"


def test_classify_week_unavailable():
    classifier = FakeClassifier(available=False)
    uc = ClassifyWeekUseCase(classifier)
    with pytest.raises(ModelsUnavailableError):
        uc.execute({
            "hours_studied": 10, "hours_sleep": 7, "hours_exercise": 3,
            "social_hours": 5, "stress_level": 6, "gpa": 3.5, "screen_hours": 4,
        })

def test_get_preventive_alerts_low_level():
    from src.application.use_cases.get_preventive_alerts import (
        GetPreventiveAlertsUseCase,
    )
    from src.application.use_cases.classify_week import ClassifyWeekUseCase
    from src.infrastructure.models.ml_predictor import MlWeeklyPredictor

    classifier = ClassifyWeekUseCase(MlWeeklyPredictor())
    use_case = GetPreventiveAlertsUseCase(classifier)
    indicators = {
        k: 0.0 for k in [
            "horas_totales", "num_actividades", "num_examenes", "num_entregas",
            "num_urgentes_48h", "num_prioridad_alta", "dias_con_actividades",
            "max_horas_dia", "concentracion_3dias", "num_sin_duracion",
        ]
    }
    result = use_case.execute(indicators)
    assert "nivel_carga" in result
    assert isinstance(result["alertas"], list)
    assert "recomendacion" in result

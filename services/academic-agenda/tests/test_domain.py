import pytest
from datetime import date, datetime

from src.domain.entities.academic_activity import AcademicActivity
from src.domain.errors import InvalidActivityError


def test_create_valid_activity():
    a = AcademicActivity(
        id=None,
        user_id=1,
        title="Tarea de matemáticas",
        course="Álgebra",
        activity_type="tarea",
        activity_date=date(2026, 11, 15),
        estimated_hours=3.5,
        priority="alta",
        description="Resolver ejercicios del capítulo 3",
        completed=False,
    )
    assert a.user_id == 1
    assert a.title == "Tarea de matemáticas"
    assert a.activity_type == "tarea"
    assert a.priority == "alta"
    assert a.completed is False


def test_invalid_activity_type():
    with pytest.raises(ValueError):
        AcademicActivity(
            id=None, user_id=1, title="T", course="C",
            activity_type="invalido", activity_date=date.today(),
            estimated_hours=1, priority="media", description="d",
            completed=False,
        )


def test_invalid_priority():
    with pytest.raises(ValueError):
        AcademicActivity(
            id=None, user_id=1, title="T", course="C",
            activity_type="tarea", activity_date=date.today(),
            estimated_hours=1, priority="urgente", description="d",
            completed=False,
        )


def test_negative_hours():
    with pytest.raises(ValueError):
        AcademicActivity(
            id=None, user_id=1, title="T", course="C",
            activity_type="tarea", activity_date=date.today(),
            estimated_hours=-1, priority="media", description="d",
            completed=False,
        )


def test_empty_title():
    with pytest.raises(ValueError):
        AcademicActivity(
            id=None, user_id=1, title="   ", course="C",
            activity_type="tarea", activity_date=date.today(),
            estimated_hours=1, priority="media", description="d",
            completed=False,
        )
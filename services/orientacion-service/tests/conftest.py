import os
import sys
import pytest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from run import create_app
from app.infrastructure.persistence.db_models import db

class TestConfig:
    TESTING = True
    # Base de datos aislada en memoria para pruebas
    SQLALCHEMY_DATABASE_URI = "sqlite:///:memory:"
    SQLALCHEMY_TRACK_MODIFICATIONS = False

@pytest.fixture
def app():
    # Inyectamos la configuracion de pruebas
    app = create_app(TestConfig)

    # Asegurarnos de limpiar la bd para cada prueba
    with app.app_context():
        db.drop_all()
        db.create_all()
        yield app
        db.drop_all()

@pytest.fixture
def client(app):
    return app.test_client()

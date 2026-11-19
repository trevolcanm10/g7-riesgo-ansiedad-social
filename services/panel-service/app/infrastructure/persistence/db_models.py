"""Modelos de persistencia del Panel Institucional.

El servicio tiene su propia base de datos y sus propias tablas. No accede a
las tablas de ningun otro microservicio.
"""

from __future__ import annotations

from flask_sqlalchemy import SQLAlchemy

from app.domain.services.fecha_hora import ahora_utc

db = SQLAlchemy()


class AtencionModel(db.Model):
    """Tabla ``atenciones`` del panel institucional."""

    __tablename__ = "atenciones"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)

    # Referencia al estudiante por su codigo. No se almacena nombre ni
    # correo: el panel trabaja con identificadores.
    estudiante_codigo = db.Column(db.String(50), nullable=False, index=True)

    # Identificador numerico del estudiante en el servicio de usuarios. Se
    # resuelve por HTTP al registrar la atencion. Permite correlacionar con
    # las evaluaciones de riesgo del servicio de evaluacion sin compartir
    # bases de datos. Nulo si no se pudo resolver.
    estudiante_id = db.Column(db.Integer, nullable=True, index=True)

    modalidad = db.Column(db.String(20), nullable=False, index=True)
    tipo = db.Column(db.String(30), nullable=False, index=True)
    estado = db.Column(db.String(20), nullable=False, default="registrada", index=True)

    # Indicadores del contrato de evaluacion de riesgo. Todos opcionales.
    phq9 = db.Column(db.Float, nullable=True)
    gad7 = db.Column(db.Float, nullable=True)
    online_stress = db.Column(db.Float, nullable=True)
    financial_stress = db.Column(db.Float, nullable=True)
    exercise_freq = db.Column(db.Float, nullable=True)
    social_activity = db.Column(db.Float, nullable=True)
    sleep_hours = db.Column(db.Float, nullable=True)

    # Cluster asignado por el modelo de agrupamiento. Nulo cuando la atencion
    # se registro sin indicadores.
    cluster_id = db.Column(db.Integer, nullable=True, index=True)

    notas = db.Column(db.Text, nullable=True)
    seguimiento_requerido = db.Column(db.Boolean, nullable=False, default=False, index=True)
    registrado_por = db.Column(db.String(120), nullable=True)

    fecha_atencion = db.Column(db.DateTime, nullable=False, index=True)
    fecha_creacion = db.Column(db.DateTime, nullable=False, default=ahora_utc)

    # Periodo ``YYYY-MM`` derivado de ``fecha_atencion``. Se calcula en Python
    # y no con una funcion de base de datos: la misma expression no existe en
    # MySQL y SQLite, y asi el repositorio funciona en ambos motores (las
    # pruebas usan SQLite en memoria). Ademas queda indexada.
    periodo = db.Column(db.String(7), nullable=False, index=True)

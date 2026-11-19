from flask_sqlalchemy import SQLAlchemy
from app.domain.entities.solicitud import utc_now

db = SQLAlchemy()


class SolicitudModel(db.Model):
    __tablename__ = "solicitudes_orientacion"

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    estudiante_id = db.Column(db.Integer, nullable=False, index=True)
    mensaje = db.Column(db.Text, nullable=False)
    comparte_evaluacion_riesgo = db.Column(db.Boolean, default=False, nullable=False)
    evaluacion_riesgo_id = db.Column(db.Integer, nullable=True)

    tema_sugerido = db.Column(db.String(50), nullable=True)
    prioridad_sugerida = db.Column(db.String(20), nullable=True, index=True)
    urgencia_detectada = db.Column(db.Boolean, default=False, nullable=False)
    estado = db.Column(db.String(20), default="pendiente", nullable=False, index=True)

    tema_confirmado = db.Column(db.String(50), nullable=True)
    prioridad_confirmada = db.Column(db.String(20), nullable=True, index=True)
    respuesta_escrita = db.Column(db.Text, nullable=True)
    atendido_por = db.Column(db.Integer, nullable=True)

    fecha_creacion = db.Column(db.DateTime, default=utc_now, nullable=False, index=True)
    fecha_atencion = db.Column(db.DateTime, nullable=True)

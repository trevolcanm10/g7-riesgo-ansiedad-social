from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

db = SQLAlchemy()

class SolicitudModel(db.Model):
    __tablename__ = 'solicitudes_orientacion'

    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    estudiante_id = db.Column(db.String(50), nullable=False)
    mensaje = db.Column(db.Text, nullable=False)
    comparte_evaluacion_riesgo = db.Column(db.Boolean, default=False)
    evaluacion_riesgo_id = db.Column(db.Integer, nullable=True)

    tema_sugerido = db.Column(db.String(50), nullable=True)
    prioridad_sugerida = db.Column(db.String(20), nullable=True)
    urgencia_detectada = db.Column(db.Boolean, default=False)
    estado = db.Column(db.String(20), default="pendiente")

    tema_confirmado = db.Column(db.String(50), nullable=True)
    prioridad_confirmada = db.Column(db.String(20), nullable=True)
    respuesta_escrita = db.Column(db.Text, nullable=True)
    atendido_por = db.Column(db.String(100), nullable=True)

    fecha_creacion = db.Column(db.DateTime, default=datetime.utcnow)
    fecha_atencion = db.Column(db.DateTime, nullable=True)

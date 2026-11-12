from typing import List, Optional
from sqlalchemy import case, desc, text
from app.application.interfaces.solicitud_repository_port import ISolicitudRepository
from app.domain.entities.solicitud import SolicitudOrientacion
from app.infrastructure.persistence.db_models import db, SolicitudModel


class SQLAlchemySolicitudRepository(ISolicitudRepository):

    def _to_domain(self, model: SolicitudModel) -> SolicitudOrientacion:
        return SolicitudOrientacion(
            id=model.id,
            estudiante_id=model.estudiante_id,
            mensaje=model.mensaje,
            comparte_evaluacion_riesgo=model.comparte_evaluacion_riesgo,
            evaluacion_riesgo_id=model.evaluacion_riesgo_id,
            tema_sugerido=model.tema_sugerido,
            prioridad_sugerida=model.prioridad_sugerida,
            urgencia_detectada=model.urgencia_detectada,
            estado=model.estado,
            tema_confirmado=model.tema_confirmado,
            prioridad_confirmada=model.prioridad_confirmada,
            respuesta_escrita=model.respuesta_escrita,
            atendido_por=model.atendido_por,
            fecha_creacion=model.fecha_creacion,
            fecha_atencion=model.fecha_atencion,
        )

    def _to_model(self, entity: SolicitudOrientacion) -> SolicitudModel:
        return SolicitudModel(
            id=entity.id,
            estudiante_id=entity.estudiante_id,
            mensaje=entity.mensaje,
            comparte_evaluacion_riesgo=entity.comparte_evaluacion_riesgo,
            evaluacion_riesgo_id=entity.evaluacion_riesgo_id,
            tema_sugerido=entity.tema_sugerido,
            prioridad_sugerida=entity.prioridad_sugerida,
            urgencia_detectada=entity.urgencia_detectada,
            estado=entity.estado,
            tema_confirmado=entity.tema_confirmado,
            prioridad_confirmada=entity.prioridad_confirmada,
            respuesta_escrita=entity.respuesta_escrita,
            atendido_por=entity.atendido_por,
            fecha_creacion=entity.fecha_creacion,
            fecha_atencion=entity.fecha_atencion,
        )

    def save(self, solicitud: SolicitudOrientacion) -> SolicitudOrientacion:
        model = self._to_model(solicitud)
        db.session.add(model)
        db.session.commit()
        return self._to_domain(model)

    def find_all(
        self,
        estado: Optional[str] = None,
        prioridad: Optional[str] = None,
        estudiante_id: Optional[int] = None,
        limit: int = 50,
        offset: int = 0,
    ) -> List[SolicitudOrientacion]:
        query = SolicitudModel.query
        prioridad_efectiva = db.func.coalesce(
            SolicitudModel.prioridad_confirmada,
            SolicitudModel.prioridad_sugerida,
        )
        if estado:
            query = query.filter_by(estado=estado)
        if prioridad:
            query = query.filter(prioridad_efectiva == prioridad)
        if estudiante_id is not None:
            query = query.filter_by(estudiante_id=estudiante_id)

        orden_prioridad = case(
            (prioridad_efectiva == "alta", 1),
            (prioridad_efectiva == "media", 2),
            (prioridad_efectiva == "baja", 3),
            else_=4,
        )
        modelos = (
            query.order_by(orden_prioridad, desc(SolicitudModel.fecha_creacion))
            .offset(offset)
            .limit(limit)
            .all()
        )
        return [self._to_domain(m) for m in modelos]

    def find_by_id(self, solicitud_id: int) -> Optional[SolicitudOrientacion]:
        model = db.session.get(SolicitudModel, solicitud_id)
        if not model:
            return None
        return self._to_domain(model)

    def update(self, solicitud: SolicitudOrientacion) -> SolicitudOrientacion:
        model = db.session.get(SolicitudModel, solicitud.id)
        if model:
            model.estado = solicitud.estado
            model.respuesta_escrita = solicitud.respuesta_escrita
            model.atendido_por = solicitud.atendido_por
            model.fecha_atencion = solicitud.fecha_atencion
            model.tema_confirmado = solicitud.tema_confirmado
            model.prioridad_confirmada = solicitud.prioridad_confirmada
            db.session.commit()
            return self._to_domain(model)
        return solicitud

    def count_by_tema(self) -> List[dict]:
        tema_efectivo = db.func.coalesce(
            SolicitudModel.tema_confirmado, SolicitudModel.tema_sugerido
        )
        metricas = (
            db.session.query(
                tema_efectivo.label("tema"),
                db.func.count(SolicitudModel.id).label("total"),
            )
            .group_by(tema_efectivo)
            .all()
        )
        return [{"tema": t[0] or "no_clasificado", "cantidad": t[1]} for t in metricas]

    def ping(self) -> bool:
        try:
            db.session.execute(text("SELECT 1"))
            return True
        except Exception:
            return False

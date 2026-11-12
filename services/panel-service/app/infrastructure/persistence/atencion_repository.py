"""Adaptador SQLAlchemy del puerto de atenciones.

Todas las consultas usan consultas parametrizadas de SQLAlchemy. No hay
concatenacion de valores en el SQL.
"""

from __future__ import annotations

from typing import Dict, List, Optional, Tuple

from sqlalchemy import func, or_

from app.application.interfaces.atencion_repository_port import IAtencionRepository
from app.domain.entities.atencion import Atencion
from app.infrastructure.persistence.db_models import AtencionModel, db

# Mapeo entre las claves del contrato de indicadores y las columnas.
COLUMNAS_INDICADORES = (
    "phq9",
    "gad7",
    "online_stress",
    "financial_stress",
    "exercise_freq",
    "social_activity",
    "sleep_hours",
)


class SQLAlchemyAtencionRepository(IAtencionRepository):
    """Implementa el puerto de atenciones sobre MySQL (o SQLite en pruebas)."""

    def guardar(self, atencion: Atencion) -> Atencion:
        """Persiste la atencion y devuelve la entidad con su identificador."""
        modelo = AtencionModel(
            estudiante_codigo=atencion.estudiante_codigo,
            estudiante_id=atencion.estudiante_id,
            modalidad=atencion.modalidad,
            tipo=atencion.tipo,
            estado=atencion.estado,
            notas=atencion.notas,
            seguimiento_requerido=atencion.seguimiento_requerido,
            registrado_por=atencion.registrado_por,
            cluster_id=atencion.cluster_id,
            fecha_atencion=atencion.fecha_atencion,
            fecha_creacion=atencion.fecha_creacion,
            periodo=atencion.fecha_atencion.strftime("%Y-%m"),
        )

        for clave in COLUMNAS_INDICADORES:
            setattr(modelo, clave, atencion.indicadores.get(clave))

        db.session.add(modelo)
        db.session.commit()

        atencion.id = modelo.id
        return atencion

    def listar(
        self,
        limite: int = 50,
        offset: int = 0,
        tipo: Optional[str] = None,
        modalidad: Optional[str] = None,
        periodo: Optional[str] = None,
    ) -> Tuple[List[Atencion], int]:
        """Devuelve una pagina de atenciones y el total del filtro."""
        consulta = AtencionModel.query
        total = self._aplicar_filtros(consulta, tipo, modalidad, periodo).count()

        modelos = (
            self._aplicar_filtros(consulta, tipo, modalidad, periodo)
            .order_by(AtencionModel.fecha_atencion.desc())
            .limit(limite)
            .offset(offset)
            .all()
        )

        return [self._a_dominio(m) for m in modelos], total

    def contar_por_dimension(
        self, dimension: str, periodo: Optional[str] = None
    ) -> List[Tuple[str, int]]:
        """Cuenta atenciones agrupadas por la dimension indicada."""
        if dimension == "periodo":
            expression = AtencionModel.periodo
        elif dimension in ("tipo", "modalidad", "estado"):
            expression = getattr(AtencionModel, dimension)
        else:
            raise ValueError(f"Dimension no soportada: {dimension}")

        consulta = db.session.query(expression.label("etiqueta"), func.count(AtencionModel.id))
        consulta = self._filtros_periodo(consulta, periodo).group_by(expression)
        consulta = consulta.order_by(func.count(AtencionModel.id).desc())

        return [(fila[0] or "sin_dato", int(fila[1])) for fila in consulta.all()]

    def contar_por_cluster(
        self, periodo: Optional[str] = None
    ) -> List[Tuple[Optional[int], int]]:
        """Cuenta atenciones agrupadas por cluster asignado."""
        consulta = db.session.query(
            AtencionModel.cluster_id.label("cluster"),
            func.count(AtencionModel.id).label("total"),
        )
        consulta = self._filtros_periodo(consulta, periodo).group_by(AtencionModel.cluster_id)
        consulta = consulta.order_by(func.count(AtencionModel.id).desc())

        return [(fila[0], int(fila[1])) for fila in consulta.all()]

    def listar_estudiantes_por_cluster(
        self, periodo: Optional[str] = None
    ) -> Dict[int, List[int]]:
        """Devuelve los identificadores de estudiantes agrupados por cluster.

        Solo incluye los estudiantes cuyo identificador se pudo resolver.
        Se usa para correlacionar con las evaluaciones de riesgo del
        microservicio de evaluacion.
        """
        consulta = db.session.query(
            AtencionModel.cluster_id.label("cluster"),
            AtencionModel.estudiante_id.label("estudiante"),
        ).filter(AtencionModel.cluster_id.isnot(None))
        consulta = self._filtros_periodo(consulta, periodo)
        consulta = consulta.filter(AtencionModel.estudiante_id.isnot(None))

        resultado: Dict[int, List[int]] = {}
        for fila in consulta.all():
            if fila[0] is None or fila[1] is None:
                continue
            resultado.setdefault(fila[0], []).append(fila[1])

        return resultado

    def contar_por_seguimiento(self, periodo: Optional[str] = None) -> int:
        """Cuenta atenciones que requieren seguimiento."""
        consulta = db.session.query(func.count(AtencionModel.id)).filter(
            AtencionModel.seguimiento_requerido.is_(True)
        )
        consulta = self._filtros_periodo(consulta, periodo)
        return int(consulta.scalar() or 0)

    def total_atencioness(self, periodo: Optional[str] = None) -> int:
        """Cuenta el total de atenciones del periodo."""
        consulta = db.session.query(func.count(AtencionModel.id))
        consulta = self._filtros_periodo(consulta, periodo)
        return int(consulta.scalar() or 0)

    def _aplicar_filtros(self, consulta, tipo, modalidad, periodo):
        """Aplica los filtros de listado a una consulta."""
        if tipo:
            consulta = consulta.filter(AtencionModel.tipo == tipo)
        if modalidad:
            consulta = consulta.filter(AtencionModel.modalidad == modalidad)
        return self._filtros_periodo(consulta, periodo)

    def _filtros_periodo(self, consulta, periodo: Optional[str]):
        """Filtra por mes cuando se indica un periodo ``YYYY-MM``."""
        if periodo:
            consulta = consulta.filter(AtencionModel.periodo == periodo)
        return consulta

    @staticmethod
    def _a_dominio(modelo: AtencionModel) -> Atencion:
        """Convierte una fila de la base de datos en la entidad de dominio."""
        indicadores = {}
        for clave in COLUMNAS_INDICADORES:
            valor = getattr(modelo, clave)
            if valor is not None:
                indicadores[clave] = float(valor)

        return Atencion(
            id=modelo.id,
            estudiante_codigo=modelo.estudiante_codigo,
            estudiante_id=modelo.estudiante_id,
            modalidad=modelo.modalidad,
            tipo=modelo.tipo,
            estado=modelo.estado,
            indicadores=indicadores,
            cluster_id=modelo.cluster_id,
            notas=modelo.notas,
            seguimiento_requerido=bool(modelo.seguimiento_requerido),
            registrado_por=modelo.registrado_por,
            fecha_atencion=modelo.fecha_atencion,
            fecha_creacion=modelo.fecha_creacion,
        )

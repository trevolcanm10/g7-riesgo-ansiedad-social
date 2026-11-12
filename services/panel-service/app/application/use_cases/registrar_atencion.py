"""Caso de uso: registrar una atencion a un estudiante.

Orquesta el registro, la asignacion de perfil de agrupamiento y la resolucion
opcional de la identidad de quien registra.
"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from app.application.interfaces.atencion_repository_port import IAtencionRepository
from app.application.interfaces.clustering_port import IClusteringPort
from app.application.interfaces.personal_externo_port import IPersonalExternoPort
from app.application.interfaces.usuarios_port import IUsuariosPort
from app.domain.entities.atencion import Atencion
from app.domain.services.fecha_hora import ahora_utc

# Nombre de las variables del contrato de evaluacion de riesgo. Coincide con
# el orden canonico del modelo de agrupamiento y con el microservicio
# prediction-ml.
INDICADORES_ESPERADOS = (
    "phq9",
    "gad7",
    "online_stress",
    "financial_stress",
    "exercise_freq",
    "social_activity",
    "sleep_hours",
)


class RegistrarAtencion:
    """Registra una atencion institucional."""

    def __init__(
        self,
        repository: IAtencionRepository,
        clustering: IClusteringPort,
        personal_externo: Optional[IPersonalExternoPort] = None,
        usuarios: Optional[IUsuariosPort] = None,
    ) -> None:
        self._repository = repository
        self._clustering = clustering
        self._personal_externo = personal_externo
        self._usuarios = usuarios

    def execute(
        self,
        *,
        estudiante_codigo: str,
        modalidad: str,
        tipo: str,
        fecha_atencion: Optional[datetime] = None,
        indicadores: Optional[dict] = None,
        notas: Optional[str] = None,
        seguimiento_requerido: bool = False,
        token: Optional[str] = None,
    ) -> Atencion:
        """Crea y persiste la atencion.

        Los indicadores son opcionales. Si se proporcionan, se asigna el
        cluster correspondiente mediante el modelo de agrupamiento; el
        resultado es una estimacion orientativa y no un diagnostico.
        """
        indicadores_validos = self._normalizar_indicadores(indicadores or {})

        atencion = Atencion(
            estudiante_codigo=estudiante_codigo,
            modalidad=modalidad,
            tipo=tipo,
            fecha_atencion=fecha_atencion or ahora_utc(),
            indicadores=indicadores_validos,
            notas=notas,
            seguimiento_requerido=seguimiento_requerido,
        )

        if indicadores_validos:
            atencion.cluster_id = self._clustering.asignar_cluster(indicadores_validos)

        # Se resuelve el identificador del estudiante por HTTP para poder
        # correlacionar con su nivel de riesgo. Si el servicio no responde, la
        # atencion se registra igual, solo sin correlacion de riesgo.
        if token and self._usuarios is not None:
            atencion.estudiante_id = self._usuarios.resolver_id(
                atencion.estudiante_codigo, token
            )

        if token and self._personal_externo is not None:
            identidad = self._personal_externo.resolver_identidad(token)
            if identidad:
                atencion.registrado_por = identidad

        return self._repository.guardar(atencion)

    @staticmethod
    def _normalizar_indicadores(indicadores: dict) -> dict:
        """Conserva solo los indicadores conocidos y con valor numerico valido."""
        validos = {}
        for clave in INDICADORES_ESPERADOS:
            valor = indicadores.get(clave)
            if valor is None:
                continue
            try:
                numero = float(valor)
            except (TypeError, ValueError):
                continue
            validos[clave] = numero
        return validos

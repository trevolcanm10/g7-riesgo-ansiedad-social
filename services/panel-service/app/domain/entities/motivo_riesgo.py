"""Motivos por los que la correlacion con el nivel de riesgo puede no estar disponible.

El panel institucional nunca falla en silencio: cuando la correlacion con el
nivel de riesgo no puede calcularse, expone el motivo para que el personal
distinga entre "falta configuracion", "el servicio rechazo el token" y "no
hay datos suficientes".
"""

from __future__ import annotations

from enum import Enum


class MotivoRiesgo(str, Enum):
    """Causa de la ausencia (o presencia) de correlacion con el nivel de riesgo."""

    DISPONIBLE = "disponible"
    NO_CONFIGURADO = "no_configurado"
    NO_AUTORIZADO = "no_autorizado"
    SERVICIO_NO_DISPONIBLE = "servicio_no_disponible"
    SIN_DATOS = "sin_datos"
    SUPRIMIDO_K5 = "suprimido_k5"

    def __str__(self) -> str:
        return self.value

"""Esquemas de validacion de la capa de presentacion (Pydantic)."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field, field_validator

from app.domain.entities.atencion import MODALIDADES, TIPOS_ATENCION


class IndicadoresAtencion(BaseModel):
    """Indicadores del contrato de evaluacion de riesgo.

    Todos son opcionales. Si se envia alguno, se valida su rango. Los rangos
    coinciden con los del microservicio ``prediction-ml``.
    """

    phq9: Optional[float] = Field(default=None, ge=0, le=27)
    gad7: Optional[float] = Field(default=None, ge=0, le=21)
    online_stress: Optional[float] = Field(default=None, ge=1, le=10)
    financial_stress: Optional[float] = Field(default=None, ge=1, le=10)
    exercise_freq: Optional[float] = Field(default=None, ge=0, le=7)
    social_activity: Optional[float] = Field(default=None, ge=0, le=10)
    sleep_hours: Optional[float] = Field(default=None, ge=3, le=10)


class AtencionCreateDTO(BaseModel):
    """Payload de registro de una atencion."""

    estudiante_codigo: str = Field(..., min_length=1, max_length=50)
    modalidad: str = Field(...)
    tipo: str = Field(...)
    fecha_atencion: Optional[datetime] = None
    indicadores: Optional[IndicadoresAtencion] = None
    notas: Optional[str] = Field(default=None, max_length=2000)
    seguimiento_requerido: bool = False

    @field_validator("modalidad")
    @classmethod
    def validar_modalidad(cls, valor: str) -> str:
        """Verifica que la modalidad sea una de las admitidas."""
        if valor not in MODALIDADES:
            raise ValueError(f"Modalidad no valida. Valores admitidos: {', '.join(MODALIDADES)}")
        return valor

    @field_validator("tipo")
    @classmethod
    def validar_tipo(cls, valor: str) -> str:
        """Verifica que el tipo sea uno de los admitidos."""
        if valor not in TIPOS_ATENCION:
            raise ValueError(f"Tipo no valido. Valores admitidos: {', '.join(TIPOS_ATENCION)}")
        return valor

    @field_validator("estudiante_codigo")
    @classmethod
    def normalizar_codigo(cls, valor: str) -> str:
        """Normaliza el codigo de estudiante."""
        limpio = valor.strip()
        if not limpio:
            raise ValueError("El codigo de estudiante es obligatorio.")
        return limpio


class PeriodoQueryDTO(BaseModel):
    """Parametro de periodo ``YYYY-MM`` usado por estadisticas e informes."""

    periodo: Optional[str] = Field(default=None, pattern=r"^\d{4}-(0[1-9]|1[0-2])$")

    @field_validator("periodo")
    @classmethod
    def normalizar_periodo(cls, valor: Optional[str]) -> Optional[str]:
        """Normaliza el periodo a mayusculas y espacios."""
        if valor is None:
            return None
        return valor.strip()

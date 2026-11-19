from typing import Literal, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class SolicitudCreateDTO(BaseModel):
    model_config = ConfigDict(extra="forbid")

    mensaje: str = Field(..., min_length=1, max_length=1500)
    comparte_evaluacion_riesgo: bool = False
    evaluacion_riesgo_id: Optional[int] = Field(default=None, gt=0)

    @field_validator("mensaje")
    @classmethod
    def validar_mensaje_no_vacio(cls, v: str) -> str:
        limpio = v.strip()
        if not limpio:
            raise ValueError("El mensaje no puede estar vacío")
        return limpio

    @model_validator(mode="after")
    def validar_coherencia_evaluacion(self) -> "SolicitudCreateDTO":
        if self.comparte_evaluacion_riesgo and self.evaluacion_riesgo_id is None:
            raise ValueError(
                "evaluacion_riesgo_id es obligatorio cuando comparte_evaluacion_riesgo es true"
            )
        if not self.comparte_evaluacion_riesgo and self.evaluacion_riesgo_id is not None:
            raise ValueError(
                "No se debe enviar evaluacion_riesgo_id cuando comparte_evaluacion_riesgo es false"
            )
        return self


class SolicitudAtenderDTO(BaseModel):
    model_config = ConfigDict(extra="forbid")

    respuesta_escrita: str = Field(..., min_length=1, max_length=3000)
    tema_confirmado: Optional[
        Literal["academico", "ansiedad_estres", "economico", "familiar", "personal"]
    ] = None
    prioridad_confirmada: Optional[Literal["alta", "media", "baja"]] = None

    @field_validator("respuesta_escrita")
    @classmethod
    def validar_respuesta_no_vacia(cls, v: str) -> str:
        limpio = v.strip()
        if not limpio:
            raise ValueError("La respuesta escrita no puede estar vacía")
        return limpio

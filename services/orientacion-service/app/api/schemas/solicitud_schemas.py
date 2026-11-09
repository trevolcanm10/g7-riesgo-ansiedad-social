from pydantic import BaseModel, Field
from typing import Optional

class SolicitudCreateDTO(BaseModel):
    estudiante_id: str = Field(..., min_length=1)
    mensaje: str = Field(..., min_length=1)
    comparte_evaluacion_riesgo: bool = False
    evaluacion_riesgo_id: Optional[int] = None

class SolicitudAtenderDTO(BaseModel):
    respuesta_escrita: str = Field(..., min_length=1)
    atendido_por: str = Field(..., min_length=1)
    tema_confirmado: Optional[str] = None
    prioridad_confirmada: Optional[str] = None

from typing import List, Optional, Dict
from datetime import datetime
from app.domain.entities.solicitud import SolicitudOrientacion
from app.domain.entities.urgencia_service import UrgenciaDomainService
from app.application.interfaces.ml_classifier_port import IMLClassifier
from app.application.interfaces.solicitud_repository_port import ISolicitudRepository

class OrientacionUseCases:
    def __init__(self, repository: ISolicitudRepository, classifier: IMLClassifier):
        self.repository = repository
        self.classifier = classifier

    def crear_solicitud(self, estudiante_id: str, mensaje: str, comparte_evaluacion: bool, eval_id: Optional[int]) -> Dict:
        # Analisis de Dominio
        urgencia = UrgenciaDomainService.detectar(mensaje)

        # Inferencia
        tema_sug, prioridad_sug = self.classifier.predict(mensaje)

        # Regla de Negocio
        if urgencia.es_urgente:
            prioridad_sug = "alta"

        solicitud = SolicitudOrientacion(
            estudiante_id=estudiante_id,
            mensaje=mensaje,
            comparte_evaluacion_riesgo=comparte_evaluacion,
            evaluacion_riesgo_id=eval_id,
            tema_sugerido=tema_sug,
            prioridad_sugerida=prioridad_sug,
            urgencia_detectada=urgencia.es_urgente
        )

        guardada = self.repository.save(solicitud)

        return {
            "solicitud": guardada,
            "urgencia": urgencia if urgencia.es_urgente else None
        }

    def listar_solicitudes(
        self,
        estado: Optional[str] = None,
        prioridad: Optional[str] = None,
        estudiante_id: Optional[str] = None,
    ) -> List[SolicitudOrientacion]:
        return self.repository.find_all(estado, prioridad, estudiante_id)

    def obtener_solicitud(self, id: int) -> Optional[SolicitudOrientacion]:
        return self.repository.find_by_id(id)

    def atender_solicitud(self, id: int, respuesta: str, orientador: str, tema_conf: Optional[str], prio_conf: Optional[str]) -> Optional[SolicitudOrientacion]:
        solicitud = self.repository.find_by_id(id)
        if not solicitud:
            return None

        solicitud.respuesta_escrita = respuesta
        solicitud.atendido_por = orientador
        solicitud.estado = "atendida"
        solicitud.fecha_atencion = datetime.utcnow()

        if tema_conf: solicitud.tema_confirmado = tema_conf
        if prio_conf: solicitud.prioridad_confirmada = prio_conf

        return self.repository.update(solicitud)

    def metricas_temas(self) -> List[dict]:
        return self.repository.count_by_tema()
